abstract final class AppStrings {
  // App
  static const String appName = 'MindsetForge';
  static const String appNamePrefix = 'Mindset';
  static const String appNameAccent = 'Forge';
  static const String appTagline = 'Rewire your mindset. Forge your future.';
  static const String appDescriptor = 'AI Mindset Coach';

  // Web auth brand hero (wide-screen marketing panel)
  static const String authEyebrow = 'YOUR DAILY MINDSET COACH';
  static const String authHeadline = 'Turn what you know into who you are.';
  static const String authSubheadline =
      'MindsetForge reprograms the beliefs beneath your decisions, day by day, until the change finally sticks.';
  static const String authFeature1Title = 'A coach that knows you';
  static const String authFeature1Body =
      'AI coaching that learns your goals and the beliefs holding you back, then meets you the moment you are stuck.';
  static const String authFeature2Title = 'A rhythm that compounds';
  static const String authFeature2Body =
      'Start mornings aligned with who you are becoming and close each night reinforcing it.';
  static const String authFeature3Title = "Today's one move";
  static const String authFeature3Body =
      'Watch limiting beliefs lose their grip as goals break down into the single action that matters now.';
  static const String authFooterNote =
      'A mindset and growth coach, not therapy or medical care.';

  // Welcome form (landing CTA pane)
  static const String welcomeFormTitle = 'Begin your transformation';
  static const String welcomeFormSubtitle =
      'Create your account and start your 7-day free trial.';

  // App store links — TODO: replace the iOS placeholder with the live App Store URL.
  static const String iosAppStoreUrl =
      'https://apps.apple.com/app/idYOUR_APP_ID';
  static const String androidPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.mindsetforge.mindsetforge';

  // Download-the-app screen (web account creation is mobile-only)
  static const String downloadTitle = 'Get the MindsetForge app';
  static const String downloadSubtitle =
      'Create your account in the MindsetForge app to get started. Subscriptions are managed in-app, so account setup happens on your phone.';
  static const String downloadIosCta = 'Download on the App Store';
  static const String downloadAndroidCta = 'Get it on Google Play';

  // Small-screen web gate (mobile web falls back to the app; see MobileWebGate)
  static const String mobileGateTitle = 'Continue in the app';
  static const String mobileGateSubtitle =
      'MindsetForge is built for your phone. Download the app for the full experience, your dashboard, coach, and daily practice.';
  static const String mobileGateOpenCta = 'Already have it? Open the app';
  static const String mobileGateDownloadLabel = 'GET THE APP';
  static const String mobileGateOpenError =
      "Couldn't open the app. Install it from your app store.";
  static const String appOpenDeepLink = 'mindsetforge://dashboard';

  // Pricing screen on web (subscriptions are mobile-only)
  static const String manageSubscriptionWebTitle =
      'Manage your subscription in the app';
  static const String manageSubscriptionWebSubtitle =
      'Subscriptions are purchased and managed in the MindsetForge mobile app. Open the app on your phone to subscribe or change your plan.';
  static const String pricingCancelAnytimeNote =
      'Cancel anytime · no questions asked';

  // Auth
  static const String getStarted = 'Get Started';
  static const String login = 'Log In';
  static const String signup = 'Create Account';
  static const String logout = 'Log Out';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String displayName = 'Your Name';
  static const String forgotPassword = 'Forgot password?';
  static const String orContinueWith = 'Or continue with';
  static const String continueWithGoogle = 'Continue with Google';
  static const String alreadyHaveAccount = 'Already have an account? ';
  static const String dontHaveAccount = "Don't have an account? ";
  static const String loginLink = 'Log in';
  static const String signupLink = 'Sign up';

  // Signup screen headings (default vs. accountability-partner invite)
  static const String signupTitle = 'Create your account';
  static const String signupSubtitle = 'Begin forging your ideal mindset';
  static const String partnerSignupTitle = 'Accept your partner invite';
  static const String partnerSignupSubtitle =
      'Create your free account to support your friend and follow their progress.';
  static const String partnerSignupBanner =
      "You've been invited to be an accountability partner. Partners join free, no subscription needed.";

  // Partner dashboard
  static const String partnerWeekTitle = 'This week';

  // Partner visibility disclosure (what a partner can / can't see)
  static const String partnerVisibilityTitle = 'What your partner can see';
  static const String partnerVisibilitySeeStreak =
      'Your streak and this week\'s consistency';
  static const String partnerVisibilitySeeProgress =
      "Today's completion progress";
  static const String partnerVisibilitySeeGoals = 'Active goals and progress';
  static const String partnerVisibilitySeeEvidence =
      "Today's evidence note, if you log one";
  static const String partnerVisibilitySeeIdentity = 'Your identity statement';
  static const String partnerVisibilitySeeSlip = 'A nudge on a day you miss';

  static const String partnerVisibilityPrivateTitle = 'Always private';
  static const String partnerVisibilityPrivateJournal = 'Journal entries';
  static const String partnerVisibilityPrivateChat = 'AI chat conversations';
  static const String partnerVisibilityPrivateBeliefs = 'Beliefs and fears';
  static const String partnerVisibilityPrivateCoach = 'Coach memory';

  // Compact one-liners for the invite prompt sheet
  static const String partnerVisibilitySeeSummary =
      'Sees your streak, daily progress, goals and a nudge if you miss a day.';
  static const String partnerVisibilityPrivateSummary =
      'Your journal, chats, beliefs and coach stay private.';

  // Legal / agreement
  static const String termsTitle = 'Terms of Service';
  static const String privacyTitle = 'Privacy Policy';
  static const String agreementPrefix =
      'By creating an account, you agree to our ';
  static const String agreementAnd = ' and ';
  static const String agreementSuffix = '.';
  static const String legalEffectivePrefix = 'Effective: ';

  // Coach disclaimer
  static const String coachDisclaimerTitle = 'Before we begin';
  static const String coachDisclaimerBody =
      'Your coach is here for mindset, goals, and beliefs, to help you grow. '
      'It is not therapy or a substitute for a licensed professional or medical '
      'care. If you are ever in crisis or thinking about harming yourself or '
      'others, please contact 988 (call or text) or your local emergency '
      'services right away.';
  static const String coachDisclaimerCta = 'I understand';
  static const String coachDisclaimerReadMore =
      'Read our Terms and Privacy Policy';

  // Manifestation system explainer
  static const String manifestationSystemTitle = 'How MindsetForge Works';
  static const String manifestationSystemIntro =
      'Most people think manifestation is positive thinking or wishing hard. It is not. Real change is a 4-layer system that starts deep in your subconscious and ends with measurable results. Each layer feeds the next.';

  static const String manifestationQuote =
      'Whatever the mind can conceive and believe, it can achieve.';
  static const String manifestationQuoteAuthor = 'Napoleon Hill';

  static const String manifestationLayer1Name = 'Subconscious';
  static const String manifestationLayer1Tagline = 'Foundation Layer';
  static const String manifestationLayer1Desc =
      'Your subconscious runs roughly 95% of your behavior. If it believes you are unworthy or incapable, you will sabotage yourself without realizing it. This is the deepest layer. Reprogram it and everything above gets easier. You rewire it two ways: affirmations train your inner voice through repetition, and visualization rehearses the outcome so vividly your brain builds the neural pathways as if it already happened.';
  static const String manifestationLayer1FedBy =
      'Morning and evening affirmations, future-self visualization';
  static const String manifestationLayer1Book =
      'From "Psycho-Cybernetics": your self-image acts as a thermostat for success. Affirmations and visualization are the fastest way to raise that set point.';

  static const String manifestationLayer2Name = 'Thoughts';
  static const String manifestationLayer2Tagline = 'Awareness Layer';
  static const String manifestationLayer2Desc =
      'Once the foundation is aligned, you train your conscious mind to think like the person you are becoming. Journaling surfaces the limiting beliefs hiding in plain sight, and coaching conversations challenge the patterns you cannot see on your own. This is how you stop drifting and start choosing your thoughts on purpose.';
  static const String manifestationLayer2FedBy =
      'Journaling and coaching conversations';
  static const String manifestationLayer2Book =
      'From "Outwitting the Devil": most people live in "drift," letting negative thoughts run the show. Winners choose their thoughts through daily reflection.';

  static const String manifestationLayer3Name = 'Actions';
  static const String manifestationLayer3Tagline = 'Discipline Layer';
  static const String manifestationLayer3Desc =
      'Beliefs and thoughts mean nothing without action. This is where most people stall. You act as if you are already the person you want to become, and small daily reps compound into momentum. Discipline, not motivation, is what carries you on the days you do not feel like it.';
  static const String manifestationLayer3FedBy = 'Habits and priority actions';
  static const String manifestationLayer3Book =
      'From "177 Mental Toughness Secrets": champions take action first and let motivation follow. Discipline is what creates freedom.';

  static const String manifestationLayer4Name = 'Results';
  static const String manifestationLayer4Tagline = 'Outcome Layer';
  static const String manifestationLayer4Desc =
      'When the three layers below are aligned, results become inevitable. Your subconscious starts hunting for evidence of your new identity, your thoughts steer you toward opportunities, and your actions build proof. Results are not the goal. They are confirmation that the inner work has landed.';
  static const String manifestationLayer4FedBy = 'Progress on your goals';
  static const String manifestationLayer4Book =
      'From "Think and Grow Rich": when desire is backed by faith it becomes an irresistible force, and faith is built by consistent evidence validating your new beliefs.';

  static const String manifestationUpstreamTitle =
      'When results stall, look upstream';
  static const String manifestationUpstreamBody =
      'Weak actions usually trace back to unexamined thoughts, which trace back to an unreprogrammed subconscious. That is why your coach works on the root, not just the symptom.';

  static const String manifestationWindowTitle = 'Why morning and evening';
  static const String manifestationWindowBody =
      'Your subconscious is most open right after you wake and just before you sleep. That is why affirmations come in a morning and an evening session. It is the difference between writing on wet clay and writing on dry.';

  static const String manifestationKeyTitle = 'The key to manifestation';
  static const String manifestationKeyBody =
      'Manifestation is not magic. It is alignment. When your subconscious beliefs, conscious thoughts, daily actions, and real-world results all point the same direction, you become unstoppable. Your alignment score shows how close those four layers are. The nearer to 100%, the faster it all moves.';

  static const String manifestationSystemCta = 'Got it';

  // Onboarding
  static const String onboardingWelcomeTitle = 'Welcome to MindsetForge';
  static const String onboardingUseDifferentAccount = 'Use a different account';
  static const String onboardingWelcomeSubtitle =
      'Your personal coaching system to rewire limiting beliefs, align your mindset, and forge the future you deserve.';
  static const String onboardingNext = 'Continue';
  static const String onboardingBack = 'Back';
  static const String onboardingAssessmentTitle = 'Your Mindset Assessment';
  static const String onboardingAssessmentSubtitle =
      'Rate yourself honestly on each trait. This is your starting point.';

  // Blueprint setup — AI-seeded trait sliders + beliefs recap
  static const String blueprintAssessmentTitle = 'Your Starting Point';
  static const String blueprintAssessmentSubtitle =
      "Here's where we think you're starting, based on what you've shared. Nudge anything that doesn't feel right.";
  static const String blueprintAssessmentLoading = 'Reading your profile...';
  static const String blueprintBeliefsRecapTitle = "What's Holding You Back";
  static const String blueprintBeliefsRecapCaption =
      'From what you shared earlier. You can refine these anytime in your Blueprint.';
  static const String blueprintBeliefsRecapEmpty =
      "You haven't named any limiting beliefs yet — you can add them anytime in your Blueprint.";
  static const String onboardingBeliefsTitle = 'Your Limiting Beliefs';
  static const String onboardingBeliefsSubtitle =
      'What stories are holding you back? Name them so we can reprogram them.';
  static const String onboardingBeliefsHint =
      'Type a belief and press Enter...';
  static const String onboardingGoalsTitle = 'Your First Goal';
  static const String onboardingGoalsSubtitle =
      'What do you want to achieve? Be specific and ambitious.';
  static const String onboardingIdentityTitle = 'Your Identity Statement';
  static const String onboardingIdentitySubtitle =
      "Who are you becoming? Write in the present tense as if it's already true.";
  static const String onboardingIdentityHint = 'I am a focused, disciplined...';
  static const String onboardingIdentityHelper = 'Help me write this';
  static const String onboardingSummaryTitle = 'Your Mindset Profile';
  static const String onboardingSummarySubtitle =
      'Here\'s what your coach sees about you right now.';
  static const String enterMindsetForge = 'Enter MindsetForge';
  static const String onboardingStartFirstRitual = 'Start My First Ritual';

  // Onboarding — goals: select + focus (two-step)
  static const String onboardingGoalsSelectTitle =
      'What do you want to achieve?';
  static const String onboardingGoalsSelectSubtitle =
      'Choose from common goals or create your own. You can pick multiple.';
  static const String onboardingGoalsSelectEmptyHint =
      'Select at least one goal to continue.';
  static const String onboardingGoalsSomethingElse = 'Something else';
  static const String onboardingGoalsSomethingElseHint = 'Write your own goal';
  static const String goalGalleryTitle = 'What do you want to achieve?';
  static const String goalGallerySubtitle =
      'Pick a starting point or write your own.';
  static const String goalStartFromScratch = 'Start from scratch';
  static const String goalStartFromScratchHint = 'Build a custom goal';
  static const String onboardingGoalsCustomAdded = 'YOUR CUSTOM GOALS';
  static const String onboardingGoalsCustomTitle = 'Custom Goal';
  static const String onboardingGoalsCustomTitleHint =
      'What do you want to achieve?';
  static const String onboardingGoalsCategoryLabel = 'Category';
  static const String onboardingGoalsAddCustom = 'Add Goal';
  static const String onboardingGoalsFocusTitle = 'Which matters most?';
  static const String onboardingGoalsFocusSubtitle =
      'Tap the goal you want to focus on first. We\'ll build your first steps around it.';
  static const String onboardingGoalsFocusTitleSingle =
      'Why does this matter to you?';
  static const String onboardingGoalsFocusSubtitleSingle =
      'A few words about why this goal matters helps your coach personalize your plan.';
  static const String onboardingGoalsChangeGoals = 'Change goals';

  // Onboarding — goals: prioritization + why
  static const String onboardingPrimaryGoalPrompt =
      'Which matters most right now?';
  static const String onboardingPrimaryGoalSubtitle =
      'Star your #1 focus. We\'ll build your first steps around it.';
  static const String onboardingPrimaryWhyPrompt =
      'Why does this one matter to you?';

  // Onboarding — blocker (AI-inferred limiting beliefs)
  static const String onboardingBlockerTitle = "What's holding you back?";
  static const String onboardingBlockerSubtitle =
      'Based on what you shared, these are the stories that often keep people stuck. Tap the ones that ring true.';
  static const String onboardingBlockerLoading = 'Reading your profile...';
  static const String onboardingBlockerCustomHint = 'Add your own...';

  // Onboarding — wide-screen companion panel recap
  static const String onboardingRecapGoalsLabel = 'YOUR GOALS';
  static const String onboardingRecapIdentityLabel = 'WHO YOU\'RE BECOMING';

  // Navigation
  static const String navHome = 'Home';
  static const String navChat = 'Chat';
  static const String navActions = 'Actions';
  static const String navJournal = 'Journal';
  static const String navMindset = 'Mindset';
  static const String navDashboard = 'Dashboard';
  static const String navCoach = 'Coach';
  static const String navSettings = 'Settings';

  // Dashboard
  static const String goodMorning = 'Good morning';
  static const String goodAfternoon = 'Good afternoon';
  static const String goodEvening = 'Good evening';
  static const String dailyWisdom = 'Daily Wisdom';
  static const String dailyWins = 'Daily Wins';
  static const String yourIdentity = 'Your Identity';
  static const String readToday = 'Read Today';
  static const String priorityActions = 'Priority Actions';
  static const String goalsSummary = 'Goals';
  static const String habitsToday = 'Habits';
  static const String alignmentScore = 'Manifestation Alignment';
  static const String evidenceLog = 'Daily Evidence';
  static const String evidencePrompt =
      'What\'s one thing you did today that proves you\'re becoming this person?';
  static const String evidenceHint = 'I showed up by...';
  static const String evidenceIdentityLabel = 'Your identity';
  // Future-self-anchored evidence framing. `{trait}` is replaced with today's
  // rotating Future Self trait at the call site.
  static const String evidenceTraitLabel = 'Your future self';
  static const String evidenceTraitPrompt =
      'Where did you act like someone who is {trait} today?';
  static const String gratitudeLog = 'Gratitude';
  static const String gratitudePrompt = 'What are you grateful for today?';
  static const String weeklyActivity = 'Weekly Activity';
  static const String groupToday = 'Today';
  static const String groupProgress = 'Your Progress';
  static const String progressTabAlignment = 'Alignment';
  static const String progressTabActivity = 'Activity';
  static const String perfectDay = 'Perfect Day';
  static const String currentStreak = 'Day Streak';
  static const String startHere = 'START HERE';
  static const String morningRoutineComplete = 'Morning Complete';
  static const String eveningRoutineComplete = 'Evening Complete';
  static const String eveningUnlocksMessage =
      'Unlocks at 5 PM · Finish morning first';
  static const String morningUnlocksMessage = 'Returns tomorrow morning';
  static const String morningSessionHero = 'MORNING SESSION';
  static const String eveningSessionHero = 'EVENING SESSION';
  static const String bonusPractice = 'BONUS PRACTICE';
  static const String focusCardChip = "TODAY'S COMMITMENT";
  static const String focusCardTitle = "Today's #1 Focus";
  static const String focusCompletedTitle = 'Focus Crushed!';
  static const String focusCompletedSubtitle =
      'Your #1 priority is done. Keep the momentum going.';

  // Today arc — phase labels + single-hero copy
  static const String phaseMorning = 'Morning';
  static const String phaseDaytime = 'Daytime';
  static const String phaseEvening = 'Evening';
  static const String heroSetFocusLabel = 'Set Your Focus';
  static const String heroSetFocusSubtitle =
      'Choose the #1 action that moves you closest to who you\'re becoming.';
  static const String heroSetFocusButton = 'Plan My Day';
  static const String heroFocusSessionLabel = "TODAY'S FOCUS";
  static const String heroFocusButton = 'Mark Complete';
  static const String heroOnTrackLabel = "You're On Track";
  static const String heroOnTrackSubtitle =
      'Your focus is done. Keep your habits rolling and ease into your evening.';
  // Embodiment lens shown on the on-track hero when a Future Self practice
  // exists. `{trait}` is replaced with today's rotating trait at the call site.
  static const String heroOnTrackTrait =
      'Now move like someone who is {trait}.';
  static const String focusStillOpenNote =
      'Your #1 focus is still open. Close it out before you wind down.';
  static const String otherRoutineMorningLink = 'Morning recap';
  static const String otherRoutineEveningLink = 'Evening routine';
  static const String dailyRoutine = 'Daily Routine';
  static const String groupHabits = 'Habits';

  // Focus win + perfect-day explainer
  static const String focusWinLabel = 'Complete Focus';
  static const String focusWinSetPrompt = 'Pick your #1 focus first';
  static const String dailyWinsInfoTitle = 'What makes a perfect day';
  static const String dailyWinsInfoBody =
      'Finish all of today\'s daily wins to earn a perfect day. Completing your '
      '#1 focus is the action that drives real change, it\'s required.';

  // Streak strip (dashboard header)
  static const String streakDayStreak = 'day streak';
  static const String streakDaysStreak = 'days streak';
  static const String streakStartToday = 'Start your streak today';
  static const String streakKeepGoing = 'Complete today to keep your streak';
  static const String streakLockedIn = 'Locked in for today. Keep it rolling';
  static const String streakPerfectWeek = 'Perfect week. You\'re unstoppable.';
  static const String streakFlawlessWeek =
      'Flawless week. Every single win, seven days straight.';
  static const String streakPerfectWeekBadge = 'PERFECT WEEK';
  static const String streakFlawlessWeekBadge = 'FLAWLESS WEEK';
  static const String streakBest = 'best';
  static const String streakToday = 'today';

  // Per-day streak recap sheet
  static const String dayRecapEmpty = 'No wins logged this day';
  static const String dayRecapPerfect = 'Perfect day';
  static const String dayRecapStreakDay = 'Streak day';
  static const String dayRecapBonus = 'Bonus';

  // Goals
  static const String goals = 'Goals';
  static const String habits = 'Habits';
  static const String addGoal = 'Add Goal';
  static const String addHabit = 'Add Habit';
  static const String editHabit = 'Edit Habit';
  static const String habitDetailTitle = 'Habit';
  static const String habitNotFound = 'Habit not found.';
  static const String habitHistoryTitle = 'History';
  static const String habitCompletionRate = 'Completion rate';
  static const String habitTotalCompletions = 'Total';
  static const String habitsActiveSectionTitle = 'Active';
  static const String habitsPausedSectionTitle = 'Paused';
  static String habitStreakMilestoneToast(String name, int days) =>
      '$name: $days-day streak! Keep it going.';
  static const String goalTitle = 'Goal Title';
  static const String goalDescription = 'Description (optional)';
  static const String goalTargetDate = 'Target Date';
  static const String goalIdentityBecomes =
      'Who do you become by achieving this?';
  static const String goalVisualization =
      'Describe achieving this goal vividly';
  static const String goalLongTerm = 'Long-term Goals';
  static const String goalShortTerm = 'Short-term Goals';
  static const String breakdownWithAI = 'Break Down';
  static const String planMyDay = 'Plan My Day';
  static const String aiSuggestions = 'Suggestions';

  // Actions screen
  static const String actionsTabPriorities = 'Priorities';
  static const String goalTargetPrefix = 'Target:';
  static const String editGoal = 'Edit Goal';
  static const String saveChanges = 'Save Changes';
  static const String goalCategory = 'Category';
  static const String fieldRequired = 'Required';
  static const String goalTitleHint = 'e.g., Build my dream business';
  static const String goalDescriptionHint = 'More details...';
  static const String goalIdentityHint =
      'e.g., I become a confident entrepreneur';

  // Guided goal creation
  static const String goalIntentionPrompt = 'What do you want to achieve?';
  static const String goalIdentityPrompt = 'Who do you become?';
  static const String goalWhyMatters = 'Why does this matter?';
  static const String goalWhyMattersHint =
      'When I achieve this, my life changes because...';
  static const String goalRefineWithAI = 'Refine with AI';
  static const String goalTimeframe = 'Timeframe';
  static const String goalTypeShort = 'Short-term';
  static const String goalTypeShortSub = '1-3 months';
  static const String goalTypeMedium = 'Medium-term';
  static const String goalTypeMediumSub = '6-12 months';
  static const String goalTypeLong = 'Long-term';
  static const String goalTypeLongSub = '2-5 years';
  static const String goalTypeLife = 'Life Goal';
  static const String goalTypeLifeSub = '5+ years';

  // Post-creation setup sheet
  static const String goalSetupTitle = 'Build your plan';
  static const String goalSetupSubtitle =
      'Your coach mapped the path. Add what resonates, you can change it anytime.';
  static const String goalSetupMilestones = 'Suggested milestones';
  static const String goalSetupMilestonesLoading = 'Mapping your milestones...';
  static const String goalSetupAddMilestone = 'Add milestone';
  static const String goalSetupReinforce = 'Reinforce it daily';
  static const String goalSetupSuggestHabit = 'Suggest a habit';
  static const String goalSetupSuggestAffirmation = 'Suggest an affirmation';
  static const String goalSetupAddHabit = 'Add habit';
  static const String goalSetupAddAffirmation = 'Add affirmation';
  static const String goalSetupHabitAdded = 'Habit added';
  static const String goalSetupAffirmationAdded = 'Affirmation added';
  static const String goalSetupFutureSelfNote =
      'This goal now feeds your Future Self Practice. Visualize it there.';
  static const String goalSetupDone = 'Done';
  static const String goalHabitAddedToast = 'Habit added to your routine!';
  static const String goalAffirmationAddedToast = 'Affirmation added!';

  // Goal detail
  static const String goalDetailTitle = 'Goal';
  static const String goalNotFound = 'This goal is no longer available.';
  static const String goalDetailDescription = 'Description';
  static const String goalDetailIdentity = 'Identity';
  static const String goalDetailActionSteps = 'Milestones';
  static const String goalDetailBreakdown = 'Suggested milestones';
  static const String goalProgressDrag = 'Drag to update';
  static const String goalMarkComplete = 'Mark as Complete';
  static const String goalAddAsSubGoal = 'Add milestone';
  static const String goalMilestoneAdded = 'Added';
  static const String goalCompletedToast =
      "Goal completed! You're unstoppable.";
  static const String goalMilestoneSavedToast = 'Milestone added!';
  static const String goalAddMilestone = 'Add milestone';
  static const String goalAddMilestoneHint = 'e.g., Ship the first version';
  static const String goalMilestoneDialogTitle = 'New milestone';
  static String goalMilestoneProgress(int done, int total) =>
      '$done of $total milestones';
  static const String goalRegenerateBreakdown = 'Suggest more';
  static const String goalCompletedSection = 'Completed';
  static const String goalNorthStar = 'North Star';
  static const String goalSetAsNorthStar = 'Set as North Star';
  static const String goalNorthStarSetToast = 'North Star updated!';

  // Priority actions (Today tab)
  static const String priorityActionsAllDone =
      "Your #1 focus is done. That's a winning day.";
  static const String priorityActionsFocusSet =
      'Complete your starred #1 focus to win the day. The rest are bonus.';
  static const String priorityActionsEmptyTitle = "Plan today's priorities";
  static const String priorityActionsEmptySubtitle =
      "Add the few actions that move you closest to who you want to become, or let your coach suggest some. Anything you don't finish rolls over to tomorrow.";
  static const String priorityActionsTodayPrefix = 'Today · ';
  static const String priorityActionsHeader = "TODAY'S PRIORITIES";
  static const String priorityActionsFocusLabel = 'TOP PRIORITY';
  static const String priorityActionsSetFocus = 'Set as top priority';
  static const String priorityActionsFocusHint =
      'Tap the star to set your #1 focus.';
  static const String priorityActionsGenerate = 'Generate ideas';
  static const String priorityActionAddHint = 'Add a priority...';

  // Habits
  static const String habitName = 'Habit Name';
  static const String habitTrigger = 'What triggers this habit?';
  static const String habitFrequency = 'Frequency';
  static const String habitIdentityReinforces =
      'What identity does this reinforce?';
  static const String streakDays = 'day streak';
  static const String dailyHabits = 'Daily Habits';
  static const String habitsAllDone = 'All habits done';
  static const String setUpHabits = 'Set up habits';
  static const String habitReminderLabel = 'Remind me';
  static const String habitReminderGuidance =
      "We'll nudge you at this time if the habit isn't done yet, mentioning your cue.";
  static const String habitPause = 'Pause';
  static const String habitResume = 'Resume';
  static const String habitDelete = 'Delete';
  static const String habitDeleteConfirmTitle = 'Delete Habit?';
  static const String habitDeleteConfirmBody =
      'This habit and its history will be permanently deleted.';
  static const String habitNameHint = 'e.g., Read one page';
  static const String habitTriggerHint = 'After I pour my morning coffee';
  static const String habitIdentityHint = 'e.g., I am a disciplined person';
  static const String habitSuggestionsTitle = 'Habit Suggestions';
  static const String habitWhenPrefix = 'When:';

  // Habit guidance (proven habit-formation framing)
  static const String habitLibraryTitle = 'Habit Library';
  static const String habitGuidanceTitle = 'What makes a habit stick';
  static const String habitGuidanceBody =
      'Keep it tiny, anchor it to something you already do, and tie it to who you want to become.';
  // Future-self framing for the habit form, used when a Future Self practice
  // exists so habits are chosen for who the user is becoming.
  static const String habitGuidanceFutureSelfTitle =
      'Borrow your future self\'s habits';
  static const String habitGuidanceFutureSelfBody =
      'What does your future self already do every day? Pick one of their habits and start it now.';
  static const String habitNameLabel = 'Habit, what will you do?';
  static const String habitNameGuidance =
      'Start tiny. Something you can do in under two minutes.';
  static const String habitCueLabel = 'Cue, when will you do it?';
  static const String habitCueGuidance =
      'Anchor it to a routine you already have so it sticks.';
  static const String habitIdentityLabel = 'Identity, who does this make you?';
  static const String habitIdentityGuidance =
      'Every time you do this, you cast a vote for this identity.';
  static const List<String> habitCuePresets = [
    'After I wake up',
    'After my morning coffee',
    'After lunch',
    'When I sit at my desk',
    'Before bed',
  ];

  // Journal
  static const String journal = 'Journal';
  static const String newEntry = 'New Entry';
  static const String modeReflect = 'Reflect';
  static const String modeGrow = 'Grow';
  static const String modePrime = 'Prime';
  static const String moodAmazing = 'Amazing';
  static const String moodGood = 'Good';
  static const String moodOkay = 'Okay';
  static const String moodStruggling = 'Struggling';
  static const String moodLow = 'Low';
  static const String generatePrompt = 'Generate Prompt';
  static const String writeYourThoughts = 'Write your thoughts...';
  static const String limitingBeliefsShifted = 'Limiting beliefs shifted';
  static const String saveEntry = 'Save Entry';

  // Chat
  static const String chatTitle = 'Chat';
  static const String back = 'Back';
  static const String coachMode = 'Coach';
  static const String futureSelfMode = 'Future Self';
  static const String newSession = 'New Session';
  static const String discussWithCoach = 'Discuss with Coach';
  static const String sessions = 'Sessions';
  static const String typeMessage = 'Type a message...';
  static const String futureSelfPlaceholder = 'Ask your future self...';
  static const String quickPromptsLabel = 'Or start with one of these:';
  static const String futureSelfQuickPromptsLabel = 'Or ask your future self:';
  static const String messageCopied = 'Copied!';
  static const String coachErrorRetry =
      'I\'m having trouble connecting right now.';
  static const String noSavedSessions = 'No saved sessions yet.';
  static const String coachIsTyping = 'Your coach is thinking...';
  static const String futureSelfIsTyping = 'Your future self is remembering...';

  // Future Self
  static const String futureSelf = 'Future Self';
  static const String futureSelfSetupTitle = 'Meet Your Future Self';
  static const String futureSelfSetupSubtitle =
      'Tell us about the person you are becoming. We\'ll channel that future version of you.';
  static const String startSession = 'Start Session';
  static const String endSession = 'End Session';
  static const String binauralFrequency = 'Binaural Frequency';

  // Future Self practice (Subconscious / Foundation layer)
  static const String futureSelfPracticeTitle = 'Future Self Practice';
  static const String futureSelfPracticeSubtitle =
      'Step into one moment as your future self. Eyes closed, guided by voice.';
  static const String futureSelfCreate = 'Create Your Practice';
  static const String futureSelfStartToday = 'Begin Today\'s Scene';
  static const String futureSelfPracticeAgain = 'Practice Again';
  static const String futureSelfCompletedToday = 'Completed Today';
  static const String futureSelfRefine = 'Refine';
  static const String futureSelfRefineNote =
      'Small refinements are okay. Repetition installs identity.';
  static const String futureSelfComplete = 'Complete Practice';
  static String futureSelfCompleteSnackBar(String minutes) =>
      'Practice complete. $minutes minutes as your future self.';
  static const String futureSelfPlayerGuidance =
      'Close your eyes and let the voice lead. Return to the same scene daily.';
  static const String futureSelfWhatTitle = 'What is Future Self Practice?';
  static const String futureSelfWhatBody =
      'You build a vivid scene of your life in the future, where your goals are already achieved and ordinary. Then, with your eyes closed, a calm voice walks you through that moment as if you are living it right now, step by step. You return to the same scene daily. The more real and detailed it feels, the more your mind treats it as your actual future, and your choices start to follow.';
  static const String futureSelfWhatExampleTitle = 'For example';
  static const String futureSelfWhatExample =
      'Picture a morning in your dream home: you wake rested, meditate, make coffee, your family joins you, you make breakfast together. You are not hoping for it. You are there, living it, and it is completely normal.';
  static const String futureSelfPrinciplesTitle = 'What makes it work';
  static const List<String> futureSelfPrinciples = [
    'Specific and vivid beats vague',
    'Already real beats someday',
    'Living it beats watching it',
    'Same scene daily beats novelty',
  ];
  static const String futureSelfBestTimeTitle = 'Best time';
  static const String futureSelfBestTimeBody =
      'Morning, before your day begins. Two to four minutes is enough, and consistency matters more than duration.';

  // Future Self "how to practice" method (primer + guide)
  static const String futureSelfHowToTitle = 'How to practice';
  static const String futureSelfHowToIntro =
      'A few minutes done well beats a long session done distracted. Put headphones on, close your eyes, and let the voice lead.';
  static const List<(String, String)> futureSelfHowToSteps = [
    (
      'Get calm first',
      'Sit comfortably, close your eyes, and breathe slowly. Let the guided breath and audio settle you. Around a minute is plenty.'
    ),
    (
      'Step into the scene',
      'Keep your eyes closed and listen. The voice places you inside your future moment. Do not watch it from outside, be there, living it in first person.'
    ),
    (
      'Make it real with your senses',
      'Feel the details as they come, the light, the sounds, the people around you. The more vivid and ordinary it feels, the deeper it lands.'
    ),
    (
      'Carry it out',
      'Before you open your eyes, take the way that future felt, and carry it into your day as though it is already yours.'
    ),
  ];
  static const String futureSelfHowToReassurance =
      'You do not need to do this perfectly. Showing up calmly each day is what creates the change.';
  static const String futureSelfHowToBegin = 'Begin Practice';

  // Future Self guided session phases (audio-first: Arrive -> Embody -> Carry)
  static const String futureSelfPhaseArriveTitle = 'Arrive';
  static const String futureSelfPhaseArriveBody =
      'Close your eyes and breathe slowly. Let your body soften and your mind grow quiet. The scene begins on its own.';
  static const String futureSelfPhaseEmbodyTitle = 'Become them';
  static const String futureSelfPhaseEmbodyBody =
      'Eyes closed. Let the voice place you inside the moment, and move through it as your future self.';
  static const String futureSelfPhaseCarryTitle = 'Carry it';
  static const String futureSelfPhaseCarryBody =
      'Hold how that felt for a few slow breaths, then bring it into your day.';
  static const String futureSelfEyesClosedHint = 'You can close your eyes now.';
  static const String futureSelfShowText = 'Show text';
  static const String futureSelfHideText = 'Hide text';
  static const String futureSelfEndSession = 'End session';
  static const String futureSelfBeginNow = 'Begin now';
  static const String futureSelfPreparing = 'Preparing your scene...';
  static const String futureSelfPreparingNote =
      'Generating your narration. First play takes a little longer.';

  // Future Self scenes
  static const String futureSelfScenesTitle = 'Your scenes';
  static const String futureSelfScenesSubtitle =
      'Short moments you return to. Pick one to practice today.';
  static const String futureSelfAddScene = 'Add a scene';
  static const String futureSelfSceneLimitReached =
      'You can keep up to three scenes. Refine or remove one to add another.';
  static const String futureSelfChooseSceneTitle = 'Choose today\'s scene';
  static const String futureSelfDeleteScene = 'Remove scene';
  static const String futureSelfDeleteSceneConfirm =
      'Remove this scene from your practice?';
  static const String futureSelfSceneBuilding = 'Building your scene...';
  static const String futureSelfSceneBuildingNote =
      'Writing your scene. Voice is generated when you first practice.';
  static const String futureSelfCreateScene = 'Create scene';
  static const String futureSelfRegenerateScene = 'Regenerate scene';
  static const String futureSelfEditIdentity = 'Edit future self';
  static const String futureSelfNewSceneTitle = 'Add a scene';
  static const String futureSelfRefineSceneTitle = 'Refine this scene';
  static const String futureSelfScenePractice = 'Practice';

  // Vision Scene Builder
  static const String futureSelfBuilderIntro =
      'Build a moment in your future where your goals are already real. The more specific and vivid — what you see, hear, smell, touch, taste, and feel — the more powerful it becomes.';
  static const String futureSelfBuilderTemplatesLabel =
      'Start from an idea (optional)';
  static const String futureSelfBuilderTemplatesHint =
      'Pick one to prefill the fields below, or write your own scene from scratch.';
  static const String futureSelfSceneTitleLabel = 'Name this scene';
  static const String futureSelfSceneTitleHint =
      'e.g. Morning in the life I built';
  static const String futureSelfSceneWhereLabel = 'Where are you?';
  static const String futureSelfSceneWhereHint =
      'Describe the place in detail — what you see, hear, smell, and feel around you.\ne.g. sunlit kitchen, marble counters, smell of fresh coffee, warm tile under my feet';
  static const String futureSelfSceneWhereHelper =
      'Include sights, sounds, smells, textures, and temperature. The more specific, the more real it feels.';
  static const String futureSelfScenePeopleLabel = "Who's with you? (optional)";
  static const String futureSelfScenePeopleHint =
      'Who is there and how does it feel to be with them?\ne.g. my partner beside me, easy and unhurried; kids laughing in the next room';
  static const String futureSelfScenePeopleHelper =
      'Describe who is present and the feeling of being together — warmth, ease, connection.';
  static const String futureSelfSceneFlowLabel = 'The flow of the scene';
  static const String futureSelfSceneFlowHint =
      'One moment per line, in order. Include what you do and what you sense in each step:\nWake up rested, light on my face\nQuiet minutes of stillness\nMake coffee — rich smell, warm mug in my hands\nSomeone joins me, easy conversation\nStep into the day feeling alive';
  static const String futureSelfSceneFlowHelper =
      'Write each moment step by step. Weave in what you see, hear, smell, touch, taste, and feel as you move through it.';
  static const String futureSelfSceneSensoryLabel =
      'Overall atmosphere (optional)';
  static const String futureSelfSceneSensoryHint =
      'The overall mood and sensory backdrop — sight, sound, smell, touch, taste, and how your body feels.\ne.g. golden light, birds outside, smell of coffee, warm mug, deep calm in my chest';
  static const String futureSelfSceneGoalsLabel =
      'Goals already achieved here (optional)';
  static const String futureSelfSceneGoalsHint =
      'Tap the goals that are already real in this scene.';
  static const String futureSelfBuilderNeedsTitle =
      'Give your scene a name to continue.';
  static const String futureSelfBuilderNeedsFlow =
      'Add at least two moments to the flow.';

  // Future Self seal / payoff moment
  static const String futureSelfSealHeadline = 'Sealed in.';
  static String futureSelfSealDaysEmbodied(int days) =>
      days <= 1 ? 'Day one embodied.' : '$days days embodied.';
  static String futureSelfSealCarryTrait(String trait) =>
      'Carry it: move like someone who is $trait today.';
  static const String futureSelfSealCarryGeneric =
      'Carry the way that felt into your next action.';
  static const String futureSelfSealLogEvidence = 'Log a piece of evidence';
  static const String futureSelfSealTalkToFutureSelf = 'Talk to your future self';
  static const String futureSelfSealDone = 'Done';

  // Affirmations
  static const String affirmations = 'Affirmations';
  static const String morningSession = 'Morning Session';
  static const String eveningSession = 'Evening Session';
  static const String addAffirmation = 'Add Affirmation';
  static const String generateAffirmations = 'Generate';
  static const String browseLibrary = 'Browse Library';
  static const String generateForMe = 'Generate for Me';
  static const String writeMyOwn = 'Write My Own';
  static const String affirmationLibraryTitle = 'Affirmation Library';
  static const String affirmationFieldHint =
      'I am confident and capable of achieving my goals';
  static const String tapNext = 'Tap to continue';
  static const String sessionComplete = 'Session Complete';

  // Affirmations — session sheet
  static const String morningAffirmationsTitle = 'Morning Affirmations';
  static const String eveningAffirmationsTitle = 'Evening Affirmations';
  static const String sessionPrevious = 'Previous';
  static const String sessionNext = 'Next';
  static const String sessionCompleteAction = 'Complete';
  static const String sessionCompleteBanner = 'Session Complete!';
  static const String affirmationSessionCoaching =
      'Read it slowly. Say it aloud if you can. Feel it as already true.';

  // Affirmations — education (intro card + how-to sheet)
  static const String affirmationsIntroTitle = 'New to affirmations?';
  static const String affirmationsIntroBody =
      'Affirmations are short, present-tense statements about the person you are becoming. Said with intention every day, they train your subconscious to believe them, and your actions follow. We added a few to get you started, tap any to edit or remove.';
  static const String affirmationsIntroLearnMore = 'Learn how to use them';

  static const String affirmationsHowToTitle = 'How affirmations work';
  static const String affirmationsHowToIntro =
      'An affirmation is a short, present-tense "I am" statement about who you are becoming. Repeated daily with real feeling, it reshapes what your subconscious believes is true, and your actions start to follow.';
  static const List<(String, String)> affirmationsHowToSteps = [
    (
      'Read it slowly',
      'Take each statement one at a time. There is no rush, let the words actually land.'
    ),
    (
      'Say it aloud',
      'Speak it out loud if you can. Hearing your own voice makes it far more real than reading it silently.'
    ),
    (
      'Feel it as already true',
      'Do not just recite the words, feel what it would feel like if it were already true. The emotion is what makes it stick.'
    ),
    (
      'Show up twice a day',
      'A morning session sets your intention, an evening session seals it in right before sleep.'
    ),
  ];
  static const String affirmationsHowToReassurance =
      'You do not need to believe it fully yet. Consistency is what turns a statement into a belief.';
  static const String affirmationsHowToSystemLink =
      'See how this fits the bigger system';
  static const String affirmationsHowToCta = 'Got it';

  // Mindset
  static const String mindset = 'Mindset';
  static const String blueprint = 'Blueprint';
  static const String blueprintChartCurrent = 'Current';
  static const String blueprintChartBaseline = 'Baseline';
  static String blueprintCalibrating(int day) =>
      'Calibrating your blueprint (day $day of 10)';
  static const String blueprintCalibratingDetail =
      'Your scores stay as you rated them until day 10, then update automatically from your activity.';
  static String blueprintLastUpdated(String when) => 'Last updated $when';
  static const String blueprintNextUpdateSunday = 'Next update Sunday';
  static const String blueprintPastSnapshots = 'History';
  static const String blueprintGrowthTitle = 'Blueprint Growth';
  static String blueprintGrowthSinceBaseline(String trait, String delta) =>
      '$delta $trait since baseline';
  static const String blueprintGrowthCalibrating =
      'Your blueprint is calibrating from your daily actions. Check back after day 10.';
  static const String blueprintGrowthAutoUpdate =
      'Your blueprint updates automatically each Sunday based on your actions.';
  static const String blueprintWeeklyUpdateTitle = 'Latest update';
  static const String alignment = 'Alignment';
  static const String progress = 'Progress';
  static const String limitingBeliefs = 'Limiting Beliefs';
  static const String masteryLevel = 'Mastery Level';
  static const String overallScore = 'Overall Score';

  // Mindset hub
  static const String mindsetHubSubtitle =
      'Daily practices to reprogram your subconscious.';
  static const String mindsetPracticeHeroLabel = "TODAY'S PRACTICE";
  static const String mindsetPracticeHeroMorningTitle = 'Morning Affirmations';
  static const String mindsetPracticeHeroMorningSubtitle =
      'Start your day by speaking your new beliefs.';
  static const String mindsetPracticeHeroMorningButton = 'Start Session';
  static const String mindsetPracticeHeroEveningTitle = 'Evening Affirmations';
  static const String mindsetPracticeHeroEveningSubtitle =
      'Close the day by reinforcing who you are becoming.';
  static const String mindsetPracticeHeroEveningButton = 'Start Session';
  static const String mindsetPracticeHeroFutureSelfTitle = 'Future Self';
  static const String mindsetPracticeHeroFutureSelfSubtitle =
      'Return to your scene and embody your future self.';
  static const String mindsetPracticeHeroFutureSelfButton = 'Start Practice';
  static const String mindsetPracticeOnTrackTitle = "You're On Track";
  static const String mindsetPracticeOnTrackSubtitle =
      'Today\'s subconscious practices are complete. Keep showing up.';
  static const String mindsetProgressEntryTitle = 'Your Progress';
  static String mindsetProgressEntryStatus(int alignment, int streak) =>
      'Alignment $alignment · $streak-day streak';
  static const String identityStatementLabel = 'IDENTITY STATEMENT';
  static const String identityStatementHint =
      'I am a disciplined, focused person who follows through';
  static const String identityStatementEmpty =
      'Set your identity statement, the person you are becoming.';

  // Mindset hub — card copy
  static const String mindsetCompleteBlueprintTitle = 'Complete your Blueprint';
  static const String mindsetCompleteBlueprintSubtitle =
      'Map your mindset traits to personalize everything';
  static const String mindsetSinceStart = 'since start';
  static String mindsetStrongestTrait(String trait) => 'Strongest trait $trait';
  static const String mindsetAlignmentTitle = 'Manifestation Alignment';
  static String mindsetAlignmentSubtitle(String level) =>
      '$level, tap for breakdown';
  static const String mindsetAffirmationsAddPrompt =
      'Add affirmations to start your daily reprogramming';
  static String mindsetAffirmationsActiveCount(int count) =>
      '$count active for morning and evening';
  static const String futureSelfVisualizePrompt =
      'Visualize the person you are becoming';
  static const String futureSelfCompletedTodayCard =
      'Completed today, you returned to the scene';
  static const String futureSelfReturnToScene =
      'Return to your scene for today';

  // Future Self practice screen
  static const String futureSelfTodayTitle = 'Today\'s Practice';
  static const String futureSelfCompletedStatus = 'Completed, nicely done.';
  static const String futureSelfNotCompletedStatus = 'Not completed yet.';
  static const String futureSelfPracticeSection = 'Your Practice';
  static const String futureSelfTimelineLabel = 'Future Timeline';
  static const String futureSelfIdentityLabel = 'Identity';
  static const String futureSelfToneLabel = 'Emotional Tone';

  // Journal
  static const String moodTrendTitle = 'Mood Trend';
  static String moodTrendAvg(String value) => 'Avg: $value/5';

  // Deep Dive
  static const String deepDiveTitle = 'Deep Dive';
  static const String deepDiveCompleteBlueprint =
      'Complete Your Blueprint First';
  static const String deepDiveGeneratingInsight = 'Generating your insight...';
  static const String deepDiveInsightLabel = 'Your Insight';
  static const String deepDiveAnswersLabel = 'Your Answers';
  static const String deepDiveSaveInsight = 'Save Insight';
  static const String deepDiveFailedInsight =
      'Failed to generate insight. Please try again.';

  // Progress
  static const String perfectDays = 'Perfect Days';
  static const String weeklyInsight = 'Weekly Insight';
  static const String weeklyInsightPattern = 'Your Pattern';
  static const String weeklyInsightBreakthrough = 'Breakthrough';
  static const String weeklyInsightFocus = 'Next Week Focus';
  static const String weeklyInsightReadyTitle = 'Your weekly review is ready';
  static const String weeklyInsightReadySubtitle =
      'Tap to see your pattern, breakthrough, and focus for the week ahead.';
  static const String weeklyInsightGenerate = 'Generate weekly insight';
  static const String weeklyInsightUnlockHint =
      'Complete 3 active days this week to unlock your review.';
  static const String weeklyInsightPastReviews = 'Past Reviews';
  static const String weeklyInsightWeekEnding = 'Week ending';
  static const String weeklyInsightRefreshLimit =
      'You can refresh your insight once per day.';
  static const String weeklyInsightNotificationTitle = 'Weekly review';
  static const String weeklyInsightNotificationSubtitle =
      'Get a push when your Sunday review is ready';
  static const String milestones = 'Milestones';

  // Alignment dimensions
  static const String subconscious = 'Subconscious';
  static const String thought = 'Thought';
  static const String action = 'Action';
  static const String results = 'Results';

  // Mastery levels
  static const String masteryAwakening = 'Awakening';
  static const String masteryShifting = 'Shifting';
  static const String masteryBuilding = 'Building';
  static const String masteryManifesting = 'Manifesting';
  static const String masteryMastery = 'Mastery';

  // Common actions
  static const String save = 'Save';
  static const String saving = 'Saving\u2026';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String done = 'Done';
  static const String add = 'Add';
  static const String skip = 'Skip';
  static const String start = 'Start';
  static const String retry = 'Retry';
  static const String loading = 'Loading...';
  static const String orLabel = 'or';

  // Empty states
  static const String noGoalsYet = 'No goals yet';
  static const String noGoalsSubtitle =
      'Add your first goal to start forging your future.';
  static const String noHabitsYet = 'Build your first habit';
  static const String noHabitsSubtitle =
      'Browse proven habits, generate ideas for your goals, or write your own.';
  static const String noJournalEntries = 'No journal entries yet';
  static const String noJournalSubtitle =
      'Start reflecting to unlock your patterns.';
  static const String noSessions = 'No sessions yet';
  static const String noSessionsSubtitle =
      'Start a conversation with your coach.';
  static const String futureSelfNoSessionsSubtitle =
      'Start a conversation with your future self.';
  static const String noAffirmations = 'Start your affirmations practice';
  static const String noAffirmationsSubtitle =
      'Affirmations are short, present-tense statements about who you are becoming. Browse the library, generate with AI, or write your own to begin.';

  // Errors
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork =
      'No connection. Check your internet and retry.';
  static const String errorAuth =
      'Authentication failed. Please check your credentials.';
  static const String errorAI =
      'Coach is unavailable. Please try again shortly.';

  // Trait names
  static const String traitConfidence = 'Confidence';
  static const String traitDiscipline = 'Discipline';
  static const String traitAbundance = 'Abundance Thinking';
  static const String traitResilience = 'Resilience';
  static const String traitDecisiveness = 'Decisiveness';

  // Category names
  static const String categoryCareer = 'Career';
  static const String categoryHealth = 'Health';
  static const String categoryRelationships = 'Relationships';
  static const String categoryFinances = 'Finances';
  static const String categoryPersonalGrowth = 'Personal Growth';
  static const String categorySpirituality = 'Spirituality';
  static const String categoryLearning = 'Learning';
  static const String categoryOther = 'Other';
  static const String categoryOtherHint = 'Name your own category';

  // Accountability partner invite prompts
  static const String invitePromptCta = 'Invite a Partner';
  static const String invitePromptNotNow = 'Not now';
  static const String invitePromptDismiss = "Don't ask again";
  static const String invitePromptManage = 'Manage partners';

  static const String invitePromptOnboardingTitle = 'Bring someone along';
  static const String invitePromptOnboardingBody =
      'People who are watched follow through. Invite a friend as your accountability partner. They get the app free and can cheer you on from day one.';

  static const String invitePromptPerfectDayTitle =
      'Perfect day! Make it stick';
  static const String invitePromptPerfectDayBody =
      'Days like this are easier with someone in your corner. Invite an accountability partner to keep the momentum going.';

  static String invitePromptStreakTitle(int days) => '$days-day streak!';
  static String invitePromptStreakBody(int days) =>
      "You're on a $days-day streak. Lock it in by inviting someone to keep you honest. They join free and can send you encouragement.";

  static const String inviteShareSubject = 'Be my accountability partner';
  static String inviteShareText(String partnerLabel, String link) =>
      "Hey $partnerLabel, I'm using MindsetForge to build a stronger mindset and I'd love you as my accountability partner. Tap to join (it's free for partners): $link";

  static const String inviteCreatedSuccess =
      'Invite link created! Share it with your partner.';
  static const String inviteLinkCopied =
      'Invite link copied to clipboard. Paste it to your partner.';
  static const String inviteCreateError =
      'Could not create invite. Please try again.';

  // Home screen widget — 7-day streak chain (focus-complete state)
  static const String widgetStreakSafe = "Today's locked in, streak safe";
  static const String widgetStreakFinish = 'finish to extend your streak';

  // Home screen widget education prompt
  static const String widgetSheetTitle = 'Keep your focus front and center';
  static const String widgetSheetBody =
      "Add the Today's Focus widget to your home screen so your #1 priority and streak greet you every time you pick up your phone.";
  static const List<String> widgetSheetStepsIos = [
    'Touch and hold an empty area of your home screen until the apps jiggle',
    'Tap the + button in the top corner',
    'Search for "MindsetForge" and pick a widget size',
    'Tap "Add Widget", then tap Done',
  ];
  static const List<String> widgetSheetStepsAndroid = [
    'Touch and hold an empty area of your home screen',
    'Tap "Widgets"',
    'Find "MindsetForge" in the list',
    "Drag the Today's Focus widget onto your home screen",
  ];
  static const String widgetSheetCta = 'Got it';
  static const String widgetSheetLater = 'Maybe later';

  // Suggested limiting beliefs
  static const List<String> suggestedBeliefs = [
    "I'm not good enough",
    "Money is hard to earn",
    "I always quit",
    "I'm not smart enough",
    "Success is for other people",
    "I don't deserve good things",
    "I'm too old / too young",
    "I'm not disciplined enough",
  ];
}
