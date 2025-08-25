;; title: NFT-Curriculum-Access
;; version: 1.0.0
;; summary: A smart contract for NFT-based curriculum access control
;; description: Schools issue NFT course passes that unlock study materials, assessments, and certification



;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-course (err u104))
(define-constant err-not-enrolled (err u105))
(define-constant err-course-not-active (err u106))
(define-constant err-assessment-not-available (err u107))
(define-constant err-insufficient-score (err u108))

;; data vars
(define-data-var last-token-id uint u0)
(define-data-var last-course-id uint u0)
(define-data-var contract-uri (optional (string-utf8 256)) none)

;; data maps
(define-map token-count principal uint)
(define-map market {token-id: uint} {price: uint, for-sale: bool})

(define-map courses uint {
    school: principal,
    name: (string-utf8 128),
    description: (string-utf8 512),
    duration-blocks: uint,
    max-enrollment: uint,
    enrollment-count: uint,
    price: uint,
    is-active: bool,
    created-at: uint
})

(define-map course-passes {token-id: uint} {
    course-id: uint,
    student: principal,
    enrolled-at: uint,
    progress: uint,
    completed: bool,
    certification-issued: bool
})

(define-map student-courses {student: principal, course-id: uint} uint)
(define-map course-materials uint (list 100 (string-utf8 256)))
(define-map course-assessments uint (list 20 {question: (string-utf8 256), correct-answer: uint}))
(define-map assessment-submissions {token-id: uint} {score: uint, submitted-at: uint, passed: bool})
(define-map authorized-schools principal bool)
(define-map certifications uint {student: principal, course-id: uint, issued-at: uint, certificate-hash: (string-utf8 64)})

;; NFT implementation
(define-non-fungible-token course-pass uint)

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id)))

(define-read-only (get-token-uri (token-id uint))
    (ok none))

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? course-pass token-id)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-unauthorized)
        (nft-transfer? course-pass token-id sender recipient)))

;; admin functions
(define-public (authorize-school (school principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set authorized-schools school true)
        (ok true)))

(define-public (revoke-school (school principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-delete authorized-schools school)
        (ok true)))

(define-read-only (is-authorized-school (school principal))
    (default-to false (map-get? authorized-schools school)))

;; course management functions
(define-public (create-course 
    (name (string-utf8 128)) 
    (description (string-utf8 512)) 
    (duration-blocks uint) 
    (max-enrollment uint) 
    (price uint))
    (let ((course-id (+ (var-get last-course-id) u1)))
        (asserts! (is-authorized-school tx-sender) err-unauthorized)
        (map-set courses course-id {
            school: tx-sender,
            name: name,
            description: description,
            duration-blocks: duration-blocks,
            max-enrollment: max-enrollment,
            enrollment-count: u0,
            price: price,
            is-active: true,
            created-at: stacks-block-height
        })
        (var-set last-course-id course-id)
        (ok course-id)))

(define-public (update-course-status (course-id uint) (is-active bool))
    (let ((course (unwrap! (map-get? courses course-id) err-not-found)))
        (asserts! (is-eq tx-sender (get school course)) err-unauthorized)
        (map-set courses course-id (merge course {is-active: is-active}))
        (ok true)))

(define-public (add-course-materials (course-id uint) (materials (list 100 (string-utf8 256))))
    (let ((course (unwrap! (map-get? courses course-id) err-not-found)))
        (asserts! (is-eq tx-sender (get school course)) err-unauthorized)
        (map-set course-materials course-id materials)
        (ok true)))

(define-public (add-course-assessments (course-id uint) (assessments (list 20 {question: (string-utf8 256), correct-answer: uint})))
    (let ((course (unwrap! (map-get? courses course-id) err-not-found)))
        (asserts! (is-eq tx-sender (get school course)) err-unauthorized)
        (map-set course-assessments course-id assessments)
        (ok true)))

;; enrollment functions
(define-public (enroll-in-course (course-id uint))
    (let ((course (unwrap! (map-get? courses course-id) err-not-found))
          (token-id (+ (var-get last-token-id) u1)))
        (asserts! (get is-active course) err-course-not-active)
        (asserts! (< (get enrollment-count course) (get max-enrollment course)) err-unauthorized)
        (asserts! (is-none (map-get? student-courses {student: tx-sender, course-id: course-id})) err-already-exists)
        
        (try! (stx-transfer? (get price course) tx-sender (get school course)))
        (try! (nft-mint? course-pass token-id tx-sender))
        
        (map-set course-passes {token-id: token-id} {
            course-id: course-id,
            student: tx-sender,
            enrolled-at: stacks-block-height,
            progress: u0,
            completed: false,
            certification-issued: false
        })
        
        (map-set student-courses {student: tx-sender, course-id: course-id} token-id)
        (map-set courses course-id (merge course {enrollment-count: (+ (get enrollment-count course) u1)}))
        (var-set last-token-id token-id)
        (ok token-id)))

;; progress tracking
(define-public (update-progress (token-id uint) (progress uint))
    (let ((pass (unwrap! (map-get? course-passes {token-id: token-id}) err-not-found)))
        (asserts! (is-eq tx-sender (get student pass)) err-unauthorized)
        (asserts! (<= progress u100) err-unauthorized)
        (map-set course-passes {token-id: token-id} (merge pass {progress: progress}))
        (ok true)))

(define-public (complete-course (token-id uint))
    (let ((pass (unwrap! (map-get? course-passes {token-id: token-id}) err-not-found)))
        (asserts! (is-eq tx-sender (get student pass)) err-unauthorized)
        (asserts! (>= (get progress pass) u100) err-unauthorized)
        (map-set course-passes {token-id: token-id} (merge pass {completed: true}))
        (ok true)))

;; assessment functions
(define-public (submit-assessment (token-id uint) (answers (list 20 uint)))
    (let ((pass (unwrap! (map-get? course-passes {token-id: token-id}) err-not-found))
          (course-id (get course-id pass))
          (assessments (unwrap! (map-get? course-assessments course-id) err-assessment-not-available)))
        (asserts! (is-eq tx-sender (get student pass)) err-unauthorized)
        (asserts! (get completed pass) err-unauthorized)
        
        (let ((score (calculate-score assessments answers)))
            (map-set assessment-submissions {token-id: token-id} {
                score: score,
                submitted-at: stacks-block-height,
                passed: (>= score u70)
            })
            (ok score))))

;; certification functions
(define-public (issue-certification (token-id uint) (certificate-hash (string-utf8 64)))
    (let ((pass (unwrap! (map-get? course-passes {token-id: token-id}) err-not-found))
          (submission (unwrap! (map-get? assessment-submissions {token-id: token-id}) err-not-found))
          (course-id (get course-id pass)))
        (asserts! (get passed submission) err-insufficient-score)
        (asserts! (not (get certification-issued pass)) err-already-exists)
        
        (map-set certifications token-id {
            student: (get student pass),
            course-id: course-id,
            issued-at: stacks-block-height,
            certificate-hash: certificate-hash
        })
        
        (map-set course-passes {token-id: token-id} (merge pass {certification-issued: true}))
        (ok true)))

;; read-only functions
(define-read-only (get-course (course-id uint))
    (map-get? courses course-id))

(define-read-only (get-course-pass (token-id uint))
    (map-get? course-passes {token-id: token-id}))

(define-read-only (get-student-course-pass (student principal) (course-id uint))
    (map-get? student-courses {student: student, course-id: course-id}))

(define-read-only (get-course-materials (course-id uint) (token-id uint))
    (let ((pass (unwrap! (map-get? course-passes {token-id: token-id}) err-not-found)))
        (if (and (is-eq (get course-id pass) course-id) 
                 (is-eq (unwrap! (nft-get-owner? course-pass token-id) err-not-found) tx-sender))
            (ok (map-get? course-materials course-id))
            err-unauthorized)))

(define-read-only (get-assessment-score (token-id uint))
    (map-get? assessment-submissions {token-id: token-id}))

(define-read-only (get-certification (token-id uint))
    (map-get? certifications token-id))

;; private functions
(define-private (calculate-score (assessments (list 20 {question: (string-utf8 256), correct-answer: uint})) (answers (list 20 uint)))
    (let ((total-questions (len assessments))
          (correct-answers (fold check-answer answers {assessments: assessments, index: u0, correct: u0})))
        (if (> total-questions u0)
            (/ (* (get correct correct-answers) u100) total-questions)
            u0)))

(define-private (check-answer (answer uint) (acc {assessments: (list 20 {question: (string-utf8 256), correct-answer: uint}), index: uint, correct: uint}))
    (let ((assessment (element-at (get assessments acc) (get index acc))))
        (if (is-some assessment)
            (if (is-eq answer (get correct-answer (unwrap-panic assessment)))
                {assessments: (get assessments acc), index: (+ (get index acc) u1), correct: (+ (get correct acc) u1)}
                {assessments: (get assessments acc), index: (+ (get index acc) u1), correct: (get correct acc)})
            acc)))
