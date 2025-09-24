# 🎓 NFT Curriculum Access

A revolutionary blockchain-based education platform where schools issue NFT "course passes" that unlock study materials, assessments, and certifications on the Stacks blockchain.

## 📋 Overview

The NFT Curriculum Access smart contract enables educational institutions to:
- 🏫 Issue NFT course passes to students
- 📚 Control access to study materials via NFT ownership
- 📝 Conduct on-chain assessments
- 🏆 Issue verified certifications upon course completion
- 💰 Monetize courses through NFT sales

## ✨ Features

- **🔐 Access Control**: Only NFT holders can access course materials
- **📊 Progress Tracking**: Monitor student progress through courses
- **🎯 Assessment System**: Built-in quiz and evaluation functionality
- **🏅 Certification**: Issue tamper-proof certificates on completion
- **🏪 Marketplace Ready**: NFT course passes can be traded
- **👩‍🏫 School Authorization**: Only authorized schools can create courses

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://docs.hiro.so/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone the repository:
```bash
git clone https://github.com/bunuz/NFT-Curriculum-Access.git
cd NFT-Curriculum-Access
```

2. Check contract syntax:
```bash
clarinet check
```

3. Run tests:
```bash
clarinet test
```

## 📖 Usage

### For Schools 🏫

#### 1. Get Authorized
```clarity
;; Contract owner must authorize your school
(contract-call? .NFT-Curriculum-Access authorize-school 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

#### 2. Create a Course
```clarity
(contract-call? .NFT-Curriculum-Access create-course 
    u"Blockchain Fundamentals" 
    u"Learn the basics of blockchain technology" 
    u1000  ;; duration in blocks
    u100   ;; max enrollment
    u1000000) ;; price in microSTX
```

#### 3. Add Course Materials
```clarity
(contract-call? .NFT-Curriculum-Access add-course-materials 
    u1 ;; course-id
    (list "Introduction to Blockchain" "Cryptography Basics" "Smart Contracts"))
```

#### 4. Add Assessments
```clarity
(contract-call? .NFT-Curriculum-Access add-course-assessments 
    u1 ;; course-id
    (list {question: u"What is a blockchain?", correct-answer: u1}
          {question: u"What is proof of work?", correct-answer: u2}))
```

### For Students 🎓

#### 1. Enroll in a Course
```clarity
;; This mints an NFT course pass and pays the school
(contract-call? .NFT-Curriculum-Access enroll-in-course u1)
```

#### 2. Access Course Materials
```clarity
;; Only works if you own the course pass NFT
(contract-call? .NFT-Curriculum-Access get-course-materials u1 u1)
```

#### 3. Update Progress
```clarity
;; Update your progress percentage (0-100)
(contract-call? .NFT-Curriculum-Access update-progress u1 u75)
```

#### 4. Complete Course
```clarity
;; Mark course as completed (requires 100% progress)
(contract-call? .NFT-Curriculum-Access complete-course u1)
```

#### 5. Take Assessment
```clarity
;; Submit answers to assessment questions
(contract-call? .NFT-Curriculum-Access submit-assessment u1 (list u1 u2 u1))
```

#### 6. Receive Certification
```clarity
;; School issues certification after passing assessment
(contract-call? .NFT-Curriculum-Access issue-certification u1 u"certificate-hash-123")
```

## 🔍 Read-Only Functions

### Course Information
```clarity
;; Get course details
(contract-call? .NFT-Curriculum-Access get-course u1)

;; Get course pass details
(contract-call? .NFT-Curriculum-Access get-course-pass u1)

;; Check if school is authorized
(contract-call? .NFT-Curriculum-Access is-authorized-school 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Student Progress
```clarity
;; Get student's course pass token ID
(contract-call? .NFT-Curriculum-Access get-student-course-pass 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM u1)

;; Get assessment score
(contract-call? .NFT-Curriculum-Access get-assessment-score u1)

;; Get certification details
(contract-call? .NFT-Curriculum-Access get-certification u1)
```

## 🛡️ Security Features

- **Owner-only functions**: Critical admin functions restricted to contract owner
- **School authorization**: Only pre-approved schools can create courses
- **NFT-gated access**: Course materials only accessible to NFT holders
- **Progress validation**: Students must complete courses before assessments
- **Score requirements**: Minimum 70% score required for certification

## 📊 Data Structures

### Course
```clarity
{
    school: principal,
    name: (string-utf8 128),
    description: (string-utf8 512),
    duration-blocks: uint,
    max-enrollment: uint,
    enrollment-count: uint,
    price: uint,
    is-active: bool,
    created-at: uint
}
```

### Course Pass NFT
```clarity
{
    course-id: uint,
    student: principal,
    enrolled-at: uint,
    progress: uint,
    completed: bool,
    certification-issued: bool
}
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly with `clarinet test`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarinet Documentation](https://docs.hiro.so/clarinet)
- [Clarity Language Reference](https://docs.stacks.co/clarity)

---

Built with ❤️ on the Stacks blockchain
