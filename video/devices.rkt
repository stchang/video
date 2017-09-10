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

;; This is the high level API for users to access the devices on their
;;   machine.
;; XXX This library is only partialy implemented!

(require racket/contract/base
         "private/devices.rkt")

(provide
 (contract-out
  [list-input-devices (-> input-devices?)]
  [input-devices? (-> any/c boolean?)]
  [screen-captures (-> input-devices? (listof string?))]
  [cameras (-> input-devices? (listof string?))]
  [audio-devices (-> input-devices? (listof string?))]))

(define (screen-captures dev)
  '())

(define (cameras dev)
  '())

(define (audio-devices dev)
  '())