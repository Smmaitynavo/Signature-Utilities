;; Signature Utilities Contract
;; A utility contract for signature generation and verification on Stacks blockchain
;; Provides helper functions for cryptographic signature operations

;; Define constants for error handling
(define-constant contract-owner tx-sender)
(define-constant err-invalid-signature (err u100))
(define-constant err-invalid-message (err u101))
(define-constant err-verification-failed (err u102))
(define-constant err-invalid-public-key (err u103))

;; Data structures for signature tracking
(define-map verified-signatures 
  {message-hash: (buff 32), public-key: (buff 33)} 
  {verified-at: uint, verified-by: principal})

(define-data-var signature-count uint u0)

;; Function 1: Generate Message Hash for Signing
;; This function takes a message and creates a standardized hash that can be signed
(define-public (generate-message-hash (message (buff 1024)))
  (begin
    ;; Validate message is not empty
    (asserts! (> (len message) u0) err-invalid-message)
    
    ;; Create a structured message for signing with domain separation
    (let ((domain-separator (unwrap-panic (as-max-len? (unwrap-panic (to-consensus-buff? "STACKS_SIGNATURE_UTILITY")) u32)))
          (structured-message (concat domain-separator message)))
      
      ;; Generate SHA256 hash of the structured message
      (let ((message-hash (sha256 structured-message)))
        (ok {
          message-hash: message-hash,
          timestamp: stacks-block-height
        })))))

;; Function 2: Verify Signature Against Message Hash
;; This function verifies that a signature is valid for a given message hash and public key
(define-public (verify-signature 
  (message-hash (buff 32))
  (signature (buff 65))  
  (public-key (buff 33)))
  (begin
    ;; Validate inputs
    (asserts! (is-eq (len message-hash) u32) err-invalid-message)
    (asserts! (is-eq (len signature) u65) err-invalid-signature)
    (asserts! (is-eq (len public-key) u33) err-invalid-public-key)
    
    ;; Perform secp256k1 signature verification
    (let ((verification-result (secp256k1-verify message-hash signature public-key)))
      (if verification-result
        (begin
          ;; Store successful verification
          (map-set verified-signatures 
            {message-hash: message-hash, public-key: public-key}
            {verified-at: stacks-block-height, verified-by: tx-sender})
          
          ;; Increment signature count
          (var-set signature-count (+ (var-get signature-count) u1))
          
          (ok {
            verified: true,
            message-hash: message-hash,
            public-key: public-key,
            verified-at: stacks-block-height,
            signature-id: (var-get signature-count)
          }))
        err-verification-failed))))

;; Read-only function to check if a signature was previously verified
(define-read-only (get-verification-status 
  (message-hash (buff 32))
  (public-key (buff 33)))
  (ok (map-get? verified-signatures {message-hash: message-hash, public-key: public-key})))

;; Read-only function to get total verified signatures count
(define-read-only (get-signature-count)
  (ok (var-get signature-count)))

;; Read-only function to get contract info
(define-read-only (get-contract-info)
  (ok {
    name: "Signature Utilities",
    version: "1.0.0",
    owner: contract-owner,
    total-verifications: (var-get signature-count)
  }))