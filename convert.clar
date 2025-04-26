;; Base58 character set
(define-constant base58-chars "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

;; Count leading '1's in the Bitcoin address
(define-private (count-leading-ones (input (string-ascii 35)))
  (fold (lambda (acc (tuple (count uint) (done bool)))
    (if (and (not (get done acc)) 
             (is-eq (element-at input (get count acc)) "1"))
      (tuple (count (+ (get count acc) u1)) (done false))
      (tuple (get count acc) (done true))))
    (tuple (count u0) (done false))
    (range u0 (length input)))
  (get count (tuple (count u0) (done false))))

;; Get Base58 character value
(define-private (char->value (c (string-ascii 1)))
  (let ((index (index-of (string-to-utf8 base58-chars) (string-to-utf8 c))))
    (if (is-none index) (err u1) (ok (unwrap-panic index))))

;; Base58 decode with proper zero-padding
(define-private (base58-decode (input (string-ascii 35)))
  (let ((leading-ones (count-leading-ones input)))
    ;; Validate all characters are Base58
    (asserts! 
      (fold (lambda (valid c) 
        (and valid (is-ok (char->value c))))
        true 
        (map element-at input (range u0 (length input))))
      (err u2))
    ;; Base58 decoding algorithm
    (let ((decoded 
            (fold (lambda (acc (list 25 uint)) (c (string-ascii 1)))
              (let ((char-val (unwrap! (char->value c) (err u3))))
                (fold (lambda (acc-byte (tuple (carry uint) (result (list 25 uint))))
                  (let ((total (+ (* (get carry) u58) char-val)))
                    (tuple 
                      (carry (div total u256)) 
                      (result (append (get result) (mod total u256))))))
                  (tuple (carry u0) (result (list))) 
                  acc))
              (tuple (carry u0) (result (list))) 
              (reverse (slice input leading-ones (length input)))))
      ;; Build final buffer with leading zeros
      (let ((decoded-bytes 
              (append 
                (map (lambda (_ uint) u0) (range u0 leading-ones)) 
                (reverse (get result decoded)))))
        (asserts! (is-eq (len decoded-bytes) u25) (err u4))
        (as-max-len? decoded-bytes u25)))))

;; Validate Bitcoin address checksum
(define-private (validate-address (data (buff 25)))
  (let ((payload (slice data u0 u21))
        (checksum (slice data u21 u25)))
    (let ((computed (slice (sha256 (sha256 payload)) u0 u4)))
      (asserts! (is-eq checksum computed) (err u5)))
    ;; Validate version byte (0x00 for P2PKH, 0x05 for P2SH)
    (let ((version (element-at data u0)))
      (asserts! (or (is-eq version u0) (is-eq version u5)) (err u6)))))

;; Convert to Stacks address
(define-public (btc->stacks (btc-address (string-ascii 35)))
  (let ((decoded (unwrap! (base58-decode btc-address) (err u100))))
    (try! (validate-address decoded))
    ;; Extract hash160 (skip version byte)
    (let ((hash160 (slice decoded u1 u21)))
      ;; Use version 22 for mainnet Stacks addresses
      (ok (c32-encode u22 hash160)))))
