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
(define-constant err-missing-prerequisites (err u109))
(define-constant err-badge-not-found (err u110))
(define-constant err-invalid-learning-path (err u111))
(define-constant err-badge-already-awarded (err u112))
(define-constant err-learning-path-not-found (err u113))
(define-constant err-prerequisites-not-met (err u114))
(define-constant err-invalid-badge-name (err u115))
(define-constant err-invalid-badge-requirements (err u116))
(define-constant err-invalid-learning-path-name (err u117))
(define-constant err-invalid-course-sequence (err u118))
(define-constant err-max-badges-reached (err u119))

;; data vars
(define-data-var last-token-id uint u0)
(define-data-var last-course-id uint u0)
(define-data-var contract-uri (optional (string-utf8 256)) none)
(define-data-var last-badge-id uint u0)
(define-data-var last-learning-path-id uint u0)
(define-data-var total-badges-awarded uint u0)

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

(define-map skill-badges uint {
    name: (string-utf8 64),
    description: (string-utf8 256),
    skill-category: (string-utf8 32),
    created-by: principal,
    badge-type: (string-utf8 16),
    requirements: (string-utf8 256),
    created-at: uint
})

(define-map student-badges {student: principal, badge-id: uint} {
    awarded-at: uint,
    course-id: (optional uint),
    verification-hash: (string-utf8 64)
})

(define-map learning-paths uint {
    name: (string-utf8 128),
    description: (string-utf8 512),
    created-by: principal,
    course-sequence: (list 10 uint),
    required-badges: (list 5 uint),
    completion-badge-id: (optional uint),
    is-active: bool,
    created-at: uint
})

(define-map course-prerequisites uint (list 5 uint))
(define-map badge-achievements principal (list 50 uint))

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
          (token-id (+ (var-get last-token-id) u1))
          (prerequisites (default-to (list) (map-get? course-prerequisites course-id))))
        (asserts! (get is-active course) err-course-not-active)
        (asserts! (< (get enrollment-count course) (get max-enrollment course)) err-unauthorized)
        (asserts! (is-none (map-get? student-courses {student: tx-sender, course-id: course-id})) err-already-exists)
        (asserts! (has-required-badges tx-sender prerequisites) err-prerequisites-not-met)
        
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

(define-public (complete-course-with-badge 
  (token-id uint)
  (badge-id (optional uint))
  (verification-hash (optional (string-utf8 64)))
)
  (let (
    (pass (unwrap! (map-get? course-passes {token-id: token-id}) err-not-found))
    (student (get student pass))
    (course-id (get course-id pass))
  )
    (asserts! (is-eq tx-sender student) err-unauthorized)
    (asserts! (>= (get progress pass) u100) err-unauthorized)
    
    (map-set course-passes {token-id: token-id} (merge pass {completed: true}))
    
    (match badge-id
      some-badge-id (
        match verification-hash
          some-hash (
            match (award-skill-badge student some-badge-id (some course-id) some-hash)
              result-ok (ok {course-completed: true, badge-awarded: true})
              result-err (ok {course-completed: true, badge-awarded: false})
          )
          (ok {course-completed: true, badge-awarded: false})
      )
      (ok {course-completed: true, badge-awarded: false})
    )
  )
)

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

;; ===== SKILL BADGE FUNCTIONS =====
(define-public (create-skill-badge
  (name (string-utf8 64))
  (description (string-utf8 256))
  (skill-category (string-utf8 32))
  (badge-type (string-utf8 16))
  (requirements (string-utf8 256))
)
  (let (
    (badge-id (var-get last-badge-id))
    (caller tx-sender)
  )
    (asserts! (is-authorized-school caller) err-unauthorized)
    (asserts! (> (len name) u0) err-invalid-badge-name)
    (asserts! (> (len description) u0) err-invalid-badge-requirements)
    
    (map-set skill-badges badge-id {
      name: name,
      description: description,
      skill-category: skill-category,
      created-by: caller,
      badge-type: badge-type,
      requirements: requirements,
      created-at: stacks-block-height
    })
    
    (var-set last-badge-id (+ badge-id u1))
    (ok badge-id)
  )
)

(define-public (award-skill-badge 
  (student principal)
  (badge-id uint)
  (course-id (optional uint))
  (verification-hash (string-utf8 64))
)
  (let (
    (caller tx-sender)
    (badge-key {student: student, badge-id: badge-id})
    (current-badges (default-to (list) (map-get? badge-achievements student)))
  )
    (asserts! (is-authorized-school caller) err-unauthorized)
    (asserts! (is-some (map-get? skill-badges badge-id)) err-badge-not-found)
    (asserts! (is-none (map-get? student-badges badge-key)) err-badge-already-awarded)
    
    (map-set student-badges badge-key {
      awarded-at: stacks-block-height,
      course-id: course-id,
      verification-hash: verification-hash
    })
    
    (map-set badge-achievements student (unwrap! (as-max-len? (append current-badges badge-id) u50) err-max-badges-reached))
    (var-set total-badges-awarded (+ (var-get total-badges-awarded) u1))
    
    (ok true)
  )
)

;; ===== LEARNING PATH FUNCTIONS =====
(define-public (create-learning-path
  (name (string-utf8 128))
  (description (string-utf8 512))
  (course-sequence (list 10 uint))
  (required-badges (list 5 uint))
  (completion-badge-id (optional uint))
)
  (let (
    (path-id (var-get last-learning-path-id))
    (caller tx-sender)
  )
    (asserts! (is-authorized-school caller) err-unauthorized)
    (asserts! (> (len name) u0) err-invalid-learning-path-name)
    (asserts! (> (len course-sequence) u0) err-invalid-course-sequence)
    
    (map-set learning-paths path-id {
      name: name,
      description: description,
      created-by: caller,
      course-sequence: course-sequence,
      required-badges: required-badges,
      completion-badge-id: completion-badge-id,
      is-active: true,
      created-at: stacks-block-height
    })
    
    (var-set last-learning-path-id (+ path-id u1))
    (ok path-id)
  )
)

(define-public (set-course-prerequisites (course-id uint) (prerequisites (list 5 uint)))
  (let ((course (unwrap! (map-get? courses course-id) err-not-found)))
    (asserts! (is-eq tx-sender (get school course)) err-unauthorized)
    (map-set course-prerequisites course-id prerequisites)
    (ok true)
  )
)

(define-public (update-learning-path-status (path-id uint) (is-active bool))
  (let ((path (unwrap! (map-get? learning-paths path-id) err-learning-path-not-found)))
    (asserts! (is-eq tx-sender (get created-by path)) err-unauthorized)
    (map-set learning-paths path-id (merge path {is-active: is-active}))
    (ok true)
  )
)

;; ===== VALIDATION FUNCTIONS =====
(define-private (has-required-badges (student principal) (required-badges (list 5 uint)))
  (let (
    (student-badge-list (default-to (list) (map-get? badge-achievements student)))
    (validation-result (fold check-badge-requirement required-badges {student-badges: student-badge-list, all-met: true}))
  )
    (get all-met validation-result)
  )
)

(define-private (check-badge-requirement 
  (badge-id uint) 
  (acc {student-badges: (list 50 uint), all-met: bool})
)
  (let (
    (has-badge (is-some (index-of (get student-badges acc) badge-id)))
  )
    {student-badges: (get student-badges acc), all-met: (and (get all-met acc) has-badge)}
  )
)

;; ===== READ-ONLY FUNCTIONS FOR BADGES & LEARNING PATHS =====
(define-read-only (get-skill-badge (badge-id uint))
  (map-get? skill-badges badge-id)
)

(define-read-only (get-student-badge (student principal) (badge-id uint))
  (map-get? student-badges {student: student, badge-id: badge-id})
)

(define-read-only (get-student-badges (student principal))
  (map-get? badge-achievements student)
)

(define-read-only (get-learning-path (path-id uint))
  (map-get? learning-paths path-id)
)

(define-read-only (get-course-prerequisites (course-id uint))
  (map-get? course-prerequisites course-id)
)

(define-read-only (can-enroll-in-course (student principal) (course-id uint))
  (let (
    (course (map-get? courses course-id))
    (prerequisites (default-to (list) (map-get? course-prerequisites course-id)))
    (already-enrolled (is-some (map-get? student-courses {student: student, course-id: course-id})))
  )
    (match course
      course-data {
        course-exists: true,
        is-active: (get is-active course-data),
        has-space: (< (get enrollment-count course-data) (get max-enrollment course-data)),
        meets-prerequisites: (has-required-badges student prerequisites),
        not-already-enrolled: (not already-enrolled),
        can-enroll: (and 
          (get is-active course-data)
          (< (get enrollment-count course-data) (get max-enrollment course-data))
          (has-required-badges student prerequisites)
          (not already-enrolled)
        )
      }
      {
        course-exists: false,
        is-active: false,
        has-space: false,
        meets-prerequisites: false,
        not-already-enrolled: true,
        can-enroll: false
      }
    )
  )
)

(define-read-only (get-badge-statistics)
  {
    total-badges-created: (var-get last-badge-id),
    total-badges-awarded: (var-get total-badges-awarded),
    total-learning-paths: (var-get last-learning-path-id)
  }
)

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
