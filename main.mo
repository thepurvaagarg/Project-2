import Map "mo:core/Map";
import Set "mo:core/Set";
import Array "mo:core/Array";
import Text "mo:core/Text";
import Time "mo:core/Time";
import Nat "mo:core/Nat";
import Principal "mo:core/Principal";
import Runtime "mo:core/Runtime";
import AccessControl "authorization/access-control";
import MixinStorage "blob-storage/Mixin";
import MixinAuthorization "authorization/MixinAuthorization";
import Stripe "stripe/stripe";
import OutCall "http-outcalls/outcall";
import Iter "mo:core/Iter";
import List "mo:core/List";

actor {
  // Authorization
  let accessControlState = AccessControl.initState();
  include MixinAuthorization(accessControlState);
  include MixinStorage();

  // Doctor profile type (with new fields)
  public type DoctorProfile = {
    name : Text;
    specialty : Text;
    country : Text;
    bio : Text;
    yearsExperience : Nat;
    rating : Nat;
    consultationFeeUsd : Nat;
    languages : [Text];
    onlineConsultations : Bool;
    isVerified : Bool;
    verificationBadge : Text;
  };

  // Community question type
  public type CommunityQuestion = {
    id : Text;
    author : Principal;
    title : Text;
    body : Text;
    tags : [Text];
    createdAt : Int;
    status : {
      #open;
      #answered;
    };
    markedHelpfulAnswerId : ?Text;
  };

  // Community answer type
  public type CommunityAnswer = {
    id : Text;
    questionId : Text;
    doctorPrincipal : Principal;
    body : Text;
    upvotes : Nat;
    createdAt : Int;
  };

  // Storage
  let questions = Map.empty<Text, CommunityQuestion>();
  let answers = Map.empty<Text, CommunityAnswer>();
  let doctorProfiles = Map.empty<Principal, DoctorProfile>();
  let answerUpvotes = Map.empty<Text, Set.Set<Principal>>();

  // Stripe configuration
  var stripeConfig : ?Stripe.StripeConfiguration = null;

  // Seed global doctor profiles
  func seedDoctors() {
    let doctor1 : DoctorProfile = {
      name = "Dr. John Smith";
      specialty = "Cardiology";
      country = "USA";
      bio = "Board certified cardiologist with 15+ years experience.";
      yearsExperience = 15;
      rating = 5;
      consultationFeeUsd = 100;
      languages = ["English", "Spanish"];
      onlineConsultations = true;
      isVerified = true;
      verificationBadge = "Board Certified";
    };

    let doctor2 : DoctorProfile = {
      name = "Dr. Emily Chen";
      specialty = "Endocrinology";
      country = "Canada";
      bio = "Specialist in diabetes and thyroid disorders.";
      yearsExperience = 12;
      rating = 4;
      consultationFeeUsd = 80;
      languages = ["English", "French"];
      onlineConsultations = true;
      isVerified = true;
      verificationBadge = "MD Verified";
    };

    let doctor3 : DoctorProfile = {
      name = "Dr. Maria Garcia";
      specialty = "Neurology";
      country = "Spain";
      bio = "Expert in neurological disorders and brain health.";
      yearsExperience = 18;
      rating = 5;
      consultationFeeUsd = 120;
      languages = ["Spanish", "English"];
      onlineConsultations = true;
      isVerified = true;
      verificationBadge = "Board Certified";
    };

    let doctor4 : DoctorProfile = {
      name = "Dr. Ahmed Hassan";
      specialty = "Orthopedics";
      country = "UAE";
      bio = "Specialized in sports medicine and joint replacement.";
      yearsExperience = 10;
      rating = 4;
      consultationFeeUsd = 90;
      languages = ["Arabic", "English"];
      onlineConsultations = true;
      isVerified = true;
      verificationBadge = "MD Verified";
    };

    let doctor5 : DoctorProfile = {
      name = "Dr. Sarah Johnson";
      specialty = "Pediatrics";
      country = "UK";
      bio = "Dedicated to children's health and development.";
      yearsExperience = 14;
      rating = 5;
      consultationFeeUsd = 85;
      languages = ["English"];
      onlineConsultations = true;
      isVerified = true;
      verificationBadge = "Board Certified";
    };

    let doctor6 : DoctorProfile = {
      name = "Dr. Yuki Tanaka";
      specialty = "Dermatology";
      country = "Japan";
      bio = "Expert in skin conditions and cosmetic dermatology.";
      yearsExperience = 11;
      rating = 4;
      consultationFeeUsd = 95;
      languages = ["Japanese", "English"];
      onlineConsultations = true;
      isVerified = true;
      verificationBadge = "MD Verified";
    };

    let doctor7 : DoctorProfile = {
      name = "Dr. Michael Brown";
      specialty = "Psychiatry";
      country = "Australia";
      bio = "Mental health specialist with focus on anxiety and depression.";
      yearsExperience = 16;
      rating = 5;
      consultationFeeUsd = 110;
      languages = ["English"];
      onlineConsultations = true;
      isVerified = true;
      verificationBadge = "Board Certified";
    };

    let doctor8 : DoctorProfile = {
      name = "Dr. Lisa Wang";
      specialty = "Oncology";
      country = "Singapore";
      bio = "Cancer treatment specialist with holistic approach.";
      yearsExperience = 13;
      rating = 5;
      consultationFeeUsd = 130;
      languages = ["English", "Mandarin"];
      onlineConsultations = true;
      isVerified = true;
      verificationBadge = "MD Verified";
    };

    doctorProfiles.add(Principal.fromText("2vxsx-fae"), doctor1);
    doctorProfiles.add(Principal.fromText("wvnth-k5a6"), doctor2);
    doctorProfiles.add(Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"), doctor3);
    doctorProfiles.add(Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai"), doctor4);
    doctorProfiles.add(Principal.fromText("r7inp-6aaaa-aaaaa-aaabq-cai"), doctor5);
    doctorProfiles.add(Principal.fromText("renrk-eyaaa-aaaaa-aaada-cai"), doctor6);
    doctorProfiles.add(Principal.fromText("qoctq-giaaa-aaaaa-aaaea-cai"), doctor7);
    doctorProfiles.add(Principal.fromText("qjdve-lqaaa-aaaaa-aaaeq-cai"), doctor8);
  };

  // Post a new question (patients only)
  public shared ({ caller }) func postQuestion(question : CommunityQuestion) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only patients can post questions");
    };

    // Verify that the question author matches the caller
    if (question.author != caller) {
      Runtime.trap("Unauthorized: Question author must match caller");
    };

    let newQuestion : CommunityQuestion = {
      question with
      author = caller;
      createdAt = Time.now();
      status = #open;
      markedHelpfulAnswerId = null;
    };

    questions.add(question.id, newQuestion);
  };

  // Get all questions (public access)
  public query func getQuestions() : async [CommunityQuestion] {
    questions.values().toArray();
  };

  // Get question by ID (public access)
  public query func getQuestionById(id : Text) : async ?CommunityQuestion {
    questions.get(id);
  };

  // Post an answer (doctors only, must be verified)
  public shared ({ caller }) func postAnswer(answer : CommunityAnswer) : async () {
    // Check that caller is an authenticated user
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only authenticated users can post answers");
    };

    // Verify that the answer's doctor principal matches the caller
    if (answer.doctorPrincipal != caller) {
      Runtime.trap("Unauthorized: Answer doctor principal must match caller");
    };

    // Check that the caller has a doctor profile and is verified
    let doctorProfile = switch (doctorProfiles.get(caller)) {
      case (null) { Runtime.trap("Unauthorized: Doctor profile not found") };
      case (?profile) { profile };
    };

    if (not doctorProfile.isVerified) {
      Runtime.trap("Unauthorized: Only verified doctors can post answers");
    };

    // Verify the question exists
    switch (questions.get(answer.questionId)) {
      case (null) { Runtime.trap("Question not found") };
      case (?_) {};
    };

    let newAnswer : CommunityAnswer = {
      answer with
      doctorPrincipal = caller;
      upvotes = 0;
      createdAt = Time.now();
    };

    answers.add(answer.id, newAnswer);
  };

  // Upvote an answer (one upvote per user per answer)
  public shared ({ caller }) func upvoteAnswer(answerId : Text) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only authenticated users can upvote");
    };

    // Get or create the upvoters set for this answer
    let upvoters = switch (answerUpvotes.get(answerId)) {
      case (null) { Set.empty<Principal>() };
      case (?set) { set };
    };

    // Check if user has already upvoted
    if (upvoters.contains(caller)) {
      Runtime.trap("Unauthorized: You can only upvote an answer once");
    };

    // Add the caller to upvoters
    upvoters.add(caller);
    answerUpvotes.add(answerId, upvoters);

    // Update answer upvote count
    let answer = switch (answers.get(answerId)) {
      case (null) { Runtime.trap("Answer not found") };
      case (?ans) { ans };
    };

    answers.add(answerId, { answer with upvotes = answer.upvotes + 1 });
  };

  // Mark an answer as helpful (only question author)
  public shared ({ caller }) func markAnswerHelpful(questionId : Text, answerId : Text) : async () {
    // Must be authenticated
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only authenticated users can mark answers as helpful");
    };

    let question = switch (questions.get(questionId)) {
      case (null) { Runtime.trap("Question not found") };
      case (?q) { q };
    };

    // Only the question author can mark an answer as helpful
    if (caller != question.author) {
      Runtime.trap("Unauthorized: Only the question author can mark an answer as helpful");
    };

    // Verify the answer exists and belongs to this question
    let answer = switch (answers.get(answerId)) {
      case (null) { Runtime.trap("Answer not found") };
      case (?ans) { ans };
    };

    if (answer.questionId != questionId) {
      Runtime.trap("Answer does not belong to this question");
    };

    questions.add(questionId, {
      question with
      markedHelpfulAnswerId = ?answerId;
      status = #answered;
    });
  };

  // Get all answers for a question (public access)
  public query func getAnswersForQuestion(questionId : Text) : async [CommunityAnswer] {
    answers.values().toArray().filter(
      func(answer : CommunityAnswer) : Bool {
        answer.questionId == questionId;
      }
    );
  };

  // Get doctor profile by principal (public access)
  public query func getDoctorByPrincipal(principal : Principal) : async ?DoctorProfile {
    doctorProfiles.get(principal);
  };

  // Stripe component functions implementation
  public query ({ caller }) func isStripeConfigured() : async Bool {
    stripeConfig != null;
  };

  public shared ({ caller }) func setStripeConfiguration(config : Stripe.StripeConfiguration) : async () {
    if (not (AccessControl.isAdmin(accessControlState, caller))) {
      Runtime.trap("Unauthorized: Only admins can perform this action");
    };
    stripeConfig := ?config;
  };

  public func getStripeSessionStatus(sessionId : Text) : async Stripe.StripeSessionStatus {
    let config = switch (stripeConfig) {
      case (null) { Runtime.trap("Stripe needs to be first configured") };
      case (?value) { value };
    };
    await Stripe.getSessionStatus(config, sessionId, transform);
  };

  public shared ({ caller }) func createCheckoutSession(items : [Stripe.ShoppingItem], successUrl : Text, cancelUrl : Text) : async Text {
    let config = switch (stripeConfig) {
      case (null) { Runtime.trap("Stripe needs to be first configured") };
      case (?value) { value };
    };
    await Stripe.createCheckoutSession(config, caller, items, successUrl, cancelUrl, transform);
  };

  public query func transform(input : OutCall.TransformationInput) : async OutCall.TransformationOutput {
    OutCall.transform(input);
  };
};
