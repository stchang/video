#lang racket/base

#|
   Copyright 2016-2017 Leif Andersen

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
|#

;; This module provides helper functions for accessing
;; I/O devices Video can make use of.

(provide (all-defined-out))
(require racket/match
         racket/set
         racket/logging
         "render-settings.rkt"
         "ffmpeg/main.rkt"
         "ffmpeg-pipeline.rkt"
         "init.rkt")

(struct input-devices (video
                       audio))
(define (mk-input-devices #:video [v '()]
                          #:audio [a '()])
  (input-devices v a))

(define (list-input-devices)
  (match (system-type 'os)
    ['unix
     (define fmt (av-find-input-format "avfoundation"))
     (define ctx (avformat-alloc-context))
     (avformat-open-input ctx "" fmt #f)
     (avdevice-list-devices ctx)]
    ['windows
     (define fmt (av-find-input-format "dshow"))
     (define ctx (avformat-alloc-context))
     (avformat-open-input ctx "dummy" fmt #f)
     (avdevice-list-devices ctx)]
    ['macosx
     (define video-devices-str "AVFoundation video devices:")
     (define audio-devices-str "AVFoundation audio devices:")
     (define dev-regexp #rx"\\[[0-9]*\\] (.*)")

     (define curr-list (box #f))
     (define video-list (box '()))
     (define audio-list (box '()))
  
     (flush-ffmpeg-log!)
     (with-intercepted-logging
         (λ (l)
           (match l
             [(vector level message data topic)
              (match message
                [(regexp video-devices-str)
                 (set-box! curr-list video-list)]
                [(regexp audio-devices-str)
                 (set-box! curr-list audio-list)]
                [_
                 (define dev-name (cadr (regexp-match dev-regexp message)))
                 (set-box! (unbox curr-list)
                           (cons dev-name (unbox (unbox curr-list))))])]))
       (λ ()
         (define fmt (av-find-input-format "avfoundation"))
         (define ctx (avformat-alloc-context))
         (with-handlers ([exn? (λ (e) (void))])
           (avformat-open-input ctx "" fmt (build-av-dict (hash "list_devices" "true"))))
         (flush-ffmpeg-log!))
       #:logger ffmpeg-logger
       'info
       (string->symbol "AVFoundation input device"))
     (input-devices (reverse (unbox video-list))
                    (reverse (unbox audio-list)))]
    [_
     (error "Not yet implemented for this platform")]))

;; Create a strean bundle out of an input device
;; nonnegative-integer nonnegative-integer render-settings -> stream-bundle
(define (devices->stream-bundle video-dev audio-dev
                                settings)
  (match settings
    [(struct* render-settings ([width width]
                               [height height]
                               [fps fps]
                               [pix-fmt pix-fmt]))
     (define os-dev
       (match (system-type 'os)
         ['macosx "avfoundation"]
         ['unix "v4l2"]
         ['windows "dshow"]
         [_
          (error "Not yet implemented for this platform")]))
     (define dev-spec
       (match (system-type 'os)
         ['macosx (format "~a:~a" video-dev audio-dev)]
         ['unix (or video-dev audio-dev)]
         ['windows
          (define vid-str (format "video=\"~a\"" video-dev))
          (define aud-str (format "audio=\"~a\"" audio-dev))
          (if (and vid-str aud-str)
              (format "~a:~a" vid-str aud-str)
              (or vid-str aud-str))]
         [_
          (error "Not yet implemented for this platform")]))
     (define fmt (av-find-input-format os-dev))
     (define ctx (avformat-alloc-context))
     (avformat-open-input ctx dev-spec fmt
                          (build-av-dict
                           (let* ([r (hash)]
                                  [r (if (and width height)
                                         (hash-set r "video_size" (format "~ax~a" width height))
                                         r)]
                                  [r (if fps
                                         (hash-set r "framerate" (format "~a" fps))
                                         r)]
                                  [r (if pix-fmt
                                         (hash-set r "pixel_format" (format "~a" pix-fmt))
                                         r)])
                             r)))]))