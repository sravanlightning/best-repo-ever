/**
 * @description       : Controller for Internal Survey Tracking - displays rotating survey questions to users on login flow
 * @author            : sravan_chava@intuit.com
 * @group             :
 * @last modified on  : 03-12-2026
 * @last modified by  : sravan_chava@intuit.com
 * @Change Log
 * Date             Author                        Description
 * 03-11-2026       sravan_chava@intuit.com         Fixed wrap-around logic - stop survey when rotation exceeds total questions
 * 03-12-2026       sravan_chava@intuit.com         Reduced SOQL queries: getDailySurvey 2→1, saveSurveyResponse 1→0, assignDailySurvey 3→2
 **/
public with sharing class InternalSurveyTrackingController {
    private static final Long MILLISECONDS_IN_DAY = 86400000;
    // ─── Cache record type / config per transaction ───────────────────────────
    private static Internal_Survey__c cachedConfig {
        get {
            if (cachedConfig == null) {
                cachedConfig = Internal_Survey__c.getInstance(UserInfo.getUserId());
            }
            return cachedConfig;
        }
        set;
    }
    /**
     * @description Returns the current survey question for the running user based on
     *              rotation logic. Returns null if rotation is complete, question already
     *              answered, or no active questions exist.
     * @author sravan_chava@intuit.com | 03-11-2026
     * @return Internal_Survey_Question__c or null
     **/
    @AuraEnabled
    public static Internal_Survey_Question__c getDailySurvey() {
        try {
            // SOQL 0: Uses custom setting getInstance — no SOQL consumed
            Internal_Survey__c config = cachedConfig;
            if (!isConfigValid(config)) return null;
            DateTime startDateTime = config.Internal_Survey_Start_Date__c;
            Decimal  intervalHours = config.Rotation_Interval_Hours__c;
            Integer  startIndex    = (Integer) config.Internal_Survey_Start_Index__c;
            Long intervalMs = (Long)(intervalHours * 60 * 60 * 1000);
            if (intervalMs <= 0) return null;

            // Pre-compute cutoff before the query so it can be used in the subquery
            DateTime cutoffTime = DateTime.newInstance(
                System.now().getTime() - intervalMs
            );
            Id userId = UserInfo.getUserId();

            // SOQL 1 (merged): Fetch all active questions with a subquery for the
            // current user's responses in the active interval window.
            // Eliminates the separate COUNT() query that previously ran after
            // determining which question to show.
            List<Internal_Survey_Question__c> questions = [
                SELECT Id,
                       Question_Text_Html__c,
                       Question_Text__c,
                       Response_Type__c,
                       Likert_Options__c,
                       Display_Order__c,
                       (SELECT Id
                        FROM   Internal_Survey_Responses__r
                        WHERE  User__c      = :userId
                          AND  CreatedDate >= :cutoffTime)
                FROM   Internal_Survey_Question__c
                WHERE  Is_Active__c     = TRUE
                  AND  Display_Order__c != null
                ORDER BY Display_Order__c ASC
            ];
            if (questions.isEmpty()) return null;
            Integer totalQuestions = questions.size();
            // Calculate which question slot we are in — strictly linear, no wrap-around
            Long msElapsed     = System.now().getTime() - startDateTime.getTime();
            Long intervalIndex = msElapsed / intervalMs;
            Long absoluteIndex = startIndex + intervalIndex;
            // ✅ Rotation has gone past the last question — stop survey entirely
            if (absoluteIndex >= totalQuestions) return null;
            Internal_Survey_Question__c currentQuestion = questions[(Integer) absoluteIndex];
            // ✅ Already answered in this window — responses were fetched in SOQL 1 above
            if (!currentQuestion.Internal_Survey_Responses__r.isEmpty()) return null;
            return currentQuestion;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'InternalSurveyTrackingController.getDailySurvey error: ' + e.getMessage());
            return null;
        }
    }
    /**
     * @description Saves the user's survey response and upserts the view tracker record.
     * @author sravan_chava@intuit.com | 03-11-2026
     * @param questionId     Id of the survey question answered
     * @param selectedOption Selected option value
     * @param freeText       Optional free-text response
     **/
    @AuraEnabled
    public static void saveSurveyResponse(Id questionId, String selectedOption, String freeText) {
        try {
            Id       userId = UserInfo.getUserId();
            DateTime now    = System.now();
            // DML 1: Insert response
            insert new Internal_Survey_Response__c(
                Survey_Question__c = questionId,
                User__c            = userId,
                Response__c        = selectedOption,
                Free_Text__c       = freeText,
                Submitted_On__c    = now
            );
            // DML 2: Upsert tracker by User__c external ID — no prior SELECT needed.
            // Salesforce matches on User__c; inserts if absent, updates if found.
            upsert new Internal_Survey_View_Tracker__c(
                User__c          = userId,
                Last_Shown__c    = now,
                Last_Question__c = questionId
            ) Internal_Survey_View_Tracker__c.User__c;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'InternalSurveyTrackingController.saveSurveyResponse error: ' + e.getMessage());
            throw new AuraHandledException('Failed to save survey response: ' + e.getMessage());
        }
    }
    /**
     * @description Assigns the next unanswered survey question to a user.
     *              Called from scheduled jobs or external processes.
     *              Skips if user was shown a question within MILLISECONDS_IN_DAY.
     * @author sravan_chava@intuit.com | 03-11-2026
     * @param userId Id of the user to assign survey to
     **/
    public static void assignDailySurvey(Id userId) {
        try {
            DateTime now = System.now();
            // SOQL 1: Check tracker — skip if shown within the day window
            List<Internal_Survey_View_Tracker__c> trackers = [
                SELECT Last_Shown__c
                FROM   Internal_Survey_View_Tracker__c
                WHERE  User__c = :userId
                LIMIT  1
            ];
            if (!trackers.isEmpty() &&
                trackers[0].Last_Shown__c != null &&
                now.getTime() - trackers[0].Last_Shown__c.getTime() < MILLISECONDS_IN_DAY) {
                return;
            }
            // SOQL 2 (merged): Get next unanswered active question using a semi-join
            // subquery to exclude questions answered in the past 30 days.
            // Replaces the two-query pattern (fetch answered IDs, then fetch questions).
            DateTime thirtyDaysAgo = now.addDays(-30);
            List<Internal_Survey_Question__c> nextQuestions = [
                SELECT Id
                FROM   Internal_Survey_Question__c
                WHERE  Is_Active__c = TRUE
                  AND  Id NOT IN (
                      SELECT Survey_Question__c
                      FROM   Internal_Survey_Response__c
                      WHERE  User__c      = :userId
                        AND  CreatedDate >= :thirtyDaysAgo
                  )
                ORDER BY Display_Order__c ASC NULLS FIRST
                LIMIT  1
            ];
            // ✅ No next question available — do not assign, do not wrap around
            if (nextQuestions.isEmpty()) return;
            // DML 1: Upsert tracker by User__c external ID
            upsert new Internal_Survey_View_Tracker__c(
                User__c          = userId,
                Last_Shown__c    = now,
                Last_Question__c = nextQuestions[0].Id
            ) Internal_Survey_View_Tracker__c.User__c;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'InternalSurveyTrackingController.assignDailySurvey error: ' + e.getMessage());
        }
    }
    // ─── Private Helpers ──────────────────────────────────────────────────────
    /**
     * @description Validates that all required config fields are present
     * @param config Internal_Survey__c custom setting instance
     * @return Boolean true if valid
     **/
    private static Boolean isConfigValid(Internal_Survey__c config) {
        return config != null
            && config.Internal_Survey_Start_Date__c  != null
            && config.Internal_Survey_Start_Index__c != null
            && config.Rotation_Interval_Hours__c     != null
            && config.Rotation_Interval_Hours__c     >  0;
    }
}
