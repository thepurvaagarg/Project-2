# MediConsult AI

## Current State
Backend generated with: patient profiles, test reports, treatments, AI analysis, doctor profiles, consultation bookings (paid via Stripe), AI doctor matching. Frontend not yet built.

## Requested Changes (Diff)

### Add
- Free community Q&A forum ("Ask a Doctor") — like Reddit/Quora but only verified/trusted doctors can answer
- Patients post health questions publicly (title + detailed description + optional tags like specialty)
- Verified doctors see all open questions and can post answers
- Patients and other users can upvote answers
- Each answer shows doctor's name, specialty, country, years of experience, and verification badge
- Questions show status: open (no answers yet), answered
- Patients can mark one answer as "Most Helpful"
- Forum is free — no payment required
- Doctor verification badge shown on all answers and doctor cards throughout the app

### Modify
- Doctor profiles: add `isVerified` boolean flag and `verificationBadge` label
- Patient dashboard: add "Community Q&A" tab alongside Reports, Treatments, Doctors, Consultations

### Remove
- Nothing removed

## Implementation Plan
1. Backend (Motoko) — extend existing backend:
   - CommunityQuestion record: id, author (Principal), title, body, tags, createdAt, status (open/answered), markedHelpfulAnswerId (optional)
   - CommunityAnswer record: id, questionId, doctorId, body, upvotes, createdAt
   - APIs: postQuestion, getQuestions, getQuestion, postAnswer, upvoteAnswer, markAnswerHelpful
   - Only verified doctors (isVerified = true) can post answers
   - DoctorProfile: add isVerified and verificationBadge fields

2. Frontend:
   - Community Q&A tab in dashboard
   - Question list page: shows all questions, filter by tag/status
   - Question detail page: shows question + all doctor answers with upvote button
   - Post question form (patients only)
   - Doctor answer form (verified doctors only)
   - Verification badge on doctor names everywhere
