/**
 * @description       : Controller for Interview Management Lightning Web Component
 * @author            : luke.vang@optum.com
 * @group             :
 * @last modified on  : 03-13-2026
 * @last modified by  : sreelatha.chalamkuri@optum.com
 * @Change Log
 * Date             Author                Description
 * 01-30-2025       Luke Vang             Adding without sharing to allow users to save the interview record without error. UW does not have access to modify opportunity object, with is master detail relationship with interview object.
 * 05-12-2025       Sreelatha Chalamkuri  Added logic to create task on case when interview is created
 * 09-13-2025       Sreelatha Chalamkuri  Added logic to create task with Type and related to member
 * 02-11-2026       Luke Vang             Added History__c query to getInterviewAuditTrail for custom history tracking and deletion audit
 * 03-13-2026       Sreelatha Chalamkuri  Fixed getInterviews to exclude Historical__c = true records so they do not block new interview creation
 **/
public with sharing class InterviewManagementController {
static LWCResponse response;
static List<SelectOption> selectOptions = new List<SelectOption>();
static String query = '';
static Id underwritingRecTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
        .get('Underwriting')
        .getRecordTypeId();
    /**
     * @description : Check if Interview is completed based on the Interview Id passed in the parameter
     * @author luke.vang@optum.com | 07-22-2024
     * @param recordId
     * @return Boolean
     **/
public static Boolean isCompleteInterview(String recordId) {
if (String.isBlank(recordId)) {
return false;
        }
List<Interview__c> interviews = (List<Interview__c>) INSCRMUtils.checkFLS(
            [
SELECT Id
FROM Interview__c
WHERE Status__c = 'Completed' AND Id = :recordId
            ],
AccessType.READABLE
        );
return !interviews.isEmpty();
    }
    /**
     * @description: Get Rule Set Id
     * @author luke.vang@optum.com | 07-15-2024
     * @param ruleSetName
     * @return LWCResponse
     **/
@AuraEnabled
public static LWCResponse getRuleSet(String ruleSetName, String recordId) {
Boolean isInterviewCompleted = isCompleteInterview(recordId);
response = new LWCResponse(false, null);
if (!INSCRMUtils.checkCRUD(Rule_Set_mdt__mdt.SObjectType, CRUD.READABLE)) {
return response;
        }
ruleSetName = '%' + ruleSetName + '%';
query = 'SELECT Id, MasterLabel FROM Rule_Set_mdt__mdt WHERE MasterLabel LIKE :ruleSetName';
if (!isInterviewCompleted) {
query += ' AND isActive__c = TRUE';
        }
List<Rule_Set_mdt__mdt> ruleSets = (List<Rule_Set_mdt__mdt>) INSCRMUtils.checkFLS(
Database.query(query),
AccessType.READABLE
        );
for (Rule_Set_mdt__mdt ruleSet : ruleSets) {
selectOptions.add(new SelectOption(ruleSet.MasterLabel, ruleSet.Id, ruleSet));
        }
if (!selectOptions.isEmpty()) {
if (selectOptions.size() == 1) {
selectOptions[0].selected = true;
            }
response = new LWCResponse(true, selectOptions);
        }
return response;
    }
    /**
     * @description : Get Group 2 Options based on the Rule Set Id
     * @author luke.vang@optum.com | 07-15-2024
     * @param ruleSetId
     * @return LWCResponse
     **/
@AuraEnabled
public static LWCResponse getGroup2Options(String ruleSetId, String recordId) {
Boolean isInterviewCompleted = isCompleteInterview(recordId);
response = new LWCResponse(false, null);
if (
!INSCRMUtils.checkCRUD(Group2_Options__mdt.SObjectType, CRUD.READABLE) &&
!INSCRMUtils.checkFLS(
Group2_Options__mdt.SObjectType,
new Set<String>{ 'Rule_Set__c', 'Has_Dependency__c', 'Id__c' },
AccessType.READABLE
            )
        ) {
return response;
        }
query = 'SELECT Id, MasterLabel, Rule_Set__c, Has_Dependency__c, Id__c FROM Group2_Options__mdt WHERE Rule_Set__c = :ruleSetId';
if (!isInterviewCompleted) {
query += ' AND isActive__c = TRUE';
        }
List<Group2_Options__mdt> group2Options = (List<Group2_Options__mdt>) INSCRMUtils.checkFLS(
Database.query(query),
AccessType.READABLE
        );
for (Group2_Options__mdt group2Option : group2Options) {
selectOptions.add(new SelectOption(group2Option.MasterLabel, group2Option.Id, group2Option));
        }
if (!selectOptions.isEmpty()) {
if (selectOptions.size() == 1) {
selectOptions[0].selected = true;
            }
response = new LWCResponse(true, selectOptions);
        }
return response;
    }
    /**
     * @description : Get Group 3 Options based on the Group 2 Option Id and Rule Set Id
     * @author luke.vang@optum.com | 07-15-2024
     * @param group2Id
     * @param ruleSetId
     * @return LWCResponse
     **/
@AuraEnabled
public static LWCResponse getGroup3Options(String group2Id, String ruleSetId, String recordId) {
Boolean isInterviewCompleted = isCompleteInterview(recordId);
response = new LWCResponse(false, null);
if (
!INSCRMUtils.checkCRUD(Group3_Options__mdt.SObjectType, CRUD.READABLE) &&
!INSCRMUtils.checkFLS(
Group3_Options__mdt.SObjectType,
new Set<String>{ 'Rule_Set__c', 'Group2_Options__c', 'Id__c' },
AccessType.READABLE
            )
        ) {
return response;
        }
query = 'SELECT Id, MasterLabel, Id__c, Rule_Set__c FROM Group3_Options__mdt WHERE Rule_Set__c = :ruleSetId AND Group2_Options__c = :group2Id';
if (!isInterviewCompleted) {
query += ' AND isActive__c = TRUE';
        }
List<Group3_Options__mdt> group3Options = (List<Group3_Options__mdt>) INSCRMUtils.checkFLS(
Database.query(query),
AccessType.READABLE
        );
for (Group3_Options__mdt group3Option : group3Options) {
selectOptions.add(new SelectOption(group3Option.MasterLabel, group3Option.Id, group3Option));
        }
if (!selectOptions.isEmpty()) {
if (selectOptions.size() == 1) {
selectOptions[0].selected = true;
            }
response = new LWCResponse(true, selectOptions);
        }
return response;
    }
    /**
     * @description : Get Interview Questions based on the Group 2 and Group 3 Option Id
     * @author luke.vang@optum.com | 07-15-2024
     * @param group2Id
     * @param group3Id
     * @return LWCResponse
     **/
@AuraEnabled
public static LWCResponse getInterviewQuestions(String group2Id, String group3Id, String recordId) {
Boolean isInterviewCompleted = isCompleteInterview(recordId);
List<Interview_Question__mdt> interviewQuestions = new List<Interview_Question__mdt>();
response = new LWCResponse(false, null);
query = 'SELECT Id, Id__c, Name__c, MasterLabel, Group2_Options__c, Group3_Options__c, Serial_Number__c, Question_Text__c FROM Interview_Question__mdt WHERE Group2_Options__c = :group2Id AND Group3_Options__c = :group3Id';
if (!isInterviewCompleted) {
query += ' AND isActive__c = TRUE';
        }
query += ' ORDER BY Serial_Number__c ASC';
List<Interview_Question__mdt> interviewQuestionsRecords = (List<Interview_Question__mdt>) INSCRMUtils.checkFLS(
Database.query(query),
AccessType.READABLE
        );
for (Interview_Question__mdt interviewQuestion : interviewQuestionsRecords) {
if (!interviewQuestion.Question_Text__c.containsIgnoreCase('CLOSING ATTESTATION: I want to thank you for')) {
interviewQuestion.Question_Text__c = interviewQuestion.Question_Text__c;
interviewQuestions.add(interviewQuestion);
            }
        }
if (!interviewQuestions.isEmpty()) {
response = new LWCResponse(true, interviewQuestions);
        }
return response;
    }
    /**
     * @description : Check if Interview exists based on the Opportunity Id passed in the parameter.
     *                Returns only non-historical interviews so that historical records do not prevent
     *                new interview creation or cause the form to enter an infinite loading state.
     * @author luke.vang@optum.com | 07-18-2024
     * @param opportunityId
     * @return LWCResponse
     **/
@AuraEnabled
public static LWCResponse getInterviews(String opportunityId) {
response = new LWCResponse(false, null);
List<Interview__c> interviews = (List<Interview__c>) INSCRMUtils.checkFLS(
            [
SELECT Id, Name, OwnerId, Status__c, CreatedDate, Completed_Date__c, Rule_Set__c, Group_2_Option__c, LastModifiedBy.Name, LastModifiedDate
FROM Interview__c
WHERE Opportunity__c = :opportunityId
AND Status__c != NULL
AND Provider_First_Call_Completed__c = false
AND Provider_Follow_Up__c = false
AND Historical__c = false
ORDER BY CreatedDate DESC
            ],
AccessType.READABLE
        );
response = new LWCResponse(true, interviews);
return response;
    }
    /**
     * @description Returns Interview__c records for the given Opportunity where
     *              Historical__c = true. Includes fields needed for the datatable:
     *              Id, Name, CreatedBy.Name, LastModifiedDate, LastModifiedBy.Name.
     * @author sreelatha.chalamkuri@optum.com | 03-13-2026
     * @param  opportunityId  Id of the Opportunity to filter by
     * @return LWCResponse with success Boolean and List<Interview__c> as data
     **/
@AuraEnabled
public static LWCResponse getHistoricalInterviews(String opportunityId) {
response = new LWCResponse(false, null);
List<Interview__c> interviews = (List<Interview__c>) INSCRMUtils.checkFLS(
            [
SELECT Id,
Name,
CreatedBy.Name,
LastModifiedDate,
LastModifiedBy.Name
FROM   Interview__c
WHERE  Opportunity__c = :opportunityId
AND  Historical__c  = TRUE
ORDER BY LastModifiedDate DESC
            ],
AccessType.READABLE
        );
response = new LWCResponse(true, interviews);
return response;
    }
@AuraEnabled
public static LWCResponse resetInterviewToInProgress(String recordId) {
response = new LWCResponse();
try {
response.success = true;
Interview__c interview = new Interview__c(Id = recordId, Status__c = 'In Progress', Completed_Date__c = null);
if (INSCRMUtils.checkCRUD(interview, CRUD.UPDATABLE)) {
update interview;
            }
        } catch (Exception ex) {
Logger.exception(ex);
response.success = false;
response.data = ex.getMessage();
        }
return response;
    }
    /**
     * @description : Save Interview based on the Interview Object passed in the payload
     * @author luke.vang@optum.com | 07-16-2024
     * @param payload
     * @return LWCResponse
     **/
@AuraEnabled
public static LWCResponse saveInterview(
String payload,
Boolean deleteAllQuestionAndResponses,
List<String> interviewResponseIdsToDelete
    ) {
try {
List<Task> taskList = new List<Task>();
response = new LWCResponse(false, null);
Interview interview = (Interview) JSON.deserialize(payload, Interview.class);
Interview__c interviewRecord = new Interview__c();
interviewRecord.Opportunity__c = interview.opportunityId;
interviewRecord.Account__c = interview.accountId;
interviewRecord.Case__c  = interview.caseId;
interviewRecord.Rule_Set__c = interview.ruleSetLabel;
interviewRecord.Group_2_Option__c = interview.group2Label;
interviewRecord.Group3_Option__c = interview.group3Label;
interviewRecord.Rule_Set_Id__c = interview.ruleSetId;
interviewRecord.Group2_Option_Id__c = interview.group2Id;
interviewRecord.Group3_Option_Id__c = interview.group3Id;
interviewRecord.Visibility__c = interview.visibility;
interviewRecord.Status__c = interview.status;
interviewRecord.Type__c = interview.type;
interviewRecord.Relation_To_Member__c = interview.relationToMember;
interviewRecord.Verbal_Authorization_Confirmed__c = interview.verbalAuthorizationConfirmed;
// Only require Type and Relation to Member for Submit (when status is Completed)
if (interviewRecord.Status__c == 'Completed') {
if (String.isBlank(interviewRecord.Type__c))
throw new AuraHandledException('Interview Type is required to submit an interview.');
if (String.isBlank(interviewRecord.Relation_To_Member__c))
throw new AuraHandledException('Relation to member is required to submit an interview.');
            }
if (interviewRecord.Status__c.equals('Completed')) {
interviewRecord.Completed_Date__c = System.now();
            }
if (interview.interviewQuestionAndAnswers.isEmpty()) {
throw new AuraHandledException(
'Interview must have at least one filled entry to save. And must be completed filled to submit the interview.'
                );
            }
if (deleteAllQuestionAndResponses && !String.isBlank(interview.id)) {
deleteAllInterviewResponses(interview.id);
            }
if (interviewResponseIdsToDelete != null && !interviewResponseIdsToDelete.isEmpty()) {
deleteIndividualInterviewResponses(interviewResponseIdsToDelete);
            }
if (!String.isBlank(interview.id)) {
interviewRecord.Id = interview.id;
if (
INSCRMUtils.checkCRUD(interviewRecord, CRUD.UPDATABLE) &&
INSCRMUtils.checkFLS(interviewRecord, AccessType.UPDATABLE)
                ) {
update interviewRecord;
List<Task> tasks = (List<Task>) INSCRMUtils.checkFLS(
                        [SELECT Id, Status, Interview__c FROM Task WHERE Interview__c = :interviewRecord.Id],
AccessType.UPDATABLE
                    );
if (!tasks.isEmpty()) {
for (Task t : tasks) {
t.Status = interviewRecord.Status__c == 'Completed' ? 'Completed' : 'Open';
                        }
update tasks;
                    }
                }
            } else {
if (
INSCRMUtils.checkCRUD(interviewRecord, CRUD.UPDATABLE) &&
INSCRMUtils.checkFLS(interviewRecord, AccessType.CREATABLE)
                ) {
insert interviewRecord;
// Re-query to ensure Name is populated (safe from LWC callout)
Interview__c ir = [
SELECT Id, Name
FROM Interview__c
WHERE Id = :interviewRecord.Id
LIMIT 1
                    ];
Opportunity opp = [
SELECT Id, Account.PersonContactId
FROM Opportunity
WHERE Id = :interviewRecord.Opportunity__c
LIMIT 1
                    ];
List<Case> cseList = [
SELECT Id, Opportunity__c,RecordTypeId
FROM Case
WHERE Opportunity__c = :interviewRecord.Opportunity__c AND RecordTypeId =:underwritingRecTypeId
                    ];
String status = interviewRecord.Status__c == 'Completed' ? 'Completed' : 'Open';
String taskRTId = Schema.SObjectType.Task.getRecordTypeInfosByName().get('UW Activity').getRecordTypeId();
Id caseId = !cseList.isEmpty() ? cseList[0].Id : null;
String subj = 'Interview' + (String.isNotBlank(ir.Name)
? ' : ' + ir.Name
:'Interview');
// Conditionally create the Case-related Task
if (caseId != null) {
Task caseTask = new Task(
Interview__c = interviewRecord.Id,
WhatId = caseId,
WhoId = opp.Account.PersonContactId,
Subject = subj,
Status = status,
RecordTypeId = taskRTId,
IsReminderSet = false,
ActivityDate = Date.today(),
Related_to_Business__c  = 'Underwriting',
Type = interviewRecord.Type__c,
Relation_to_Member__c  = interviewRecord.Relation_To_Member__c
                        );
taskList.add(caseTask);
                    }
if (!taskList.isEmpty() && INSCRMUtils.checkCRUD(taskList[0], CRUD.CREATABLE) &&
INSCRMUtils.checkFLS(taskList[0], AccessType.CREATABLE)) {
insert taskList;
                     }
                }
            }
if (interview.interviewQuestionAndAnswers != null) {
List<Interview_Question_Response__c> interviewQuestionResponses = new List<Interview_Question_Response__c>();
List<InterviewQuestionAndAnswer> interviewQuestionsAndAnswers = (List<InterviewQuestionAndAnswer>) JSON.deserialize(
JSON.serialize(interview.interviewQuestionAndAnswers),
List<InterviewQuestionAndAnswer>.class
                );
for (InterviewQuestionAndAnswer interviewQuestionAndAnswer : interviewQuestionsAndAnswers) {
Interview_Question_Response__c interviewQuestionResponse = new Interview_Question_Response__c();
interviewQuestionResponse.Interview__c = interviewRecord.Id;
interviewQuestionResponse.Question_Text__c = interviewQuestionAndAnswer.question;
interviewQuestionResponse.Answer__c = interviewQuestionAndAnswer.answer;
interviewQuestionResponse.Question_Id__c = interviewQuestionAndAnswer.questionId;
if (!String.isBlank(interviewQuestionAndAnswer.serialNumber)) {
interviewQuestionResponse.Serial_Number__c = Integer.valueOf(interviewQuestionAndAnswer.serialNumber);
                    }
if (interviewQuestionAndAnswer.id != null) {
interviewQuestionResponse.Id = interviewQuestionAndAnswer.id;
                    }
interviewQuestionResponses.add(interviewQuestionResponse);
                }
if (interviewQuestionResponses.size() > 0) {
if (
INSCRMUtils.checkCRUD(interviewQuestionResponses[0], CRUD.UPSERTABLE) &&
INSCRMUtils.checkFLS(interviewQuestionResponses[0], AccessType.UPSERTABLE)
                    ) {
upsert interviewQuestionResponses;
                    }
                }
            }
response = new LWCResponse(true, interviewRecord.Id);
        } catch (Exception ex) {
Logger.exception(ex);
response = new LWCResponse(false, ex.getMessage() + ex.getStackTraceString());
        }
return response;
    }
    /**
     * @description : Get Interview based on the Interview Id
     * @author luke.vang@optum.com | 07-16-2024
     * @param recordId
     * @return LWCResponse
     **/
@AuraEnabled
public static LWCResponse getInterview(String recordId) {
try {
response = new LWCResponse(false, null);
Interview interview = new Interview();
Interview__c interviewRecord = ((List<Interview__c>) INSCRMUtils.checkFLS(
                [
SELECT
Id,
Opportunity__c,
Rule_Set__c,
Group_2_Option__c,
Group3_Option__c,
Rule_Set_Id__c,
Group2_Option_Id__c,
Group3_Option_Id__c,
Status__c,
Visibility__c,
Type__c,
Relation_To_Member__c,
Verbal_Authorization_Confirmed__c,
                        (
SELECT Id, Answer__c, Question_Text__c, Serial_Number__c, Question_Id__c,
Address_Answer__Street__s,
Address_Answer__City__s,
Address_Answer__StateCode__s,
Address_Answer__PostalCode__s,
Address_Answer__CountryCode__s,
Address_Answer__c, Checkbox_Answer__c,
Date_Answer__c,
DateTime_Answer__c,
Multi_Select_Answer__c, Phone_Answer__c, Picklist_Answer__c
FROM Interview_Question_Responses__r
ORDER BY Serial_Number__c ASC
                        )
FROM Interview__c
WHERE Id = :recordId
                ],
AccessType.READABLE
            ))[0];
interview.opportunityId = interviewRecord.Opportunity__c;
interview.ruleSetLabel = interviewRecord.Rule_Set__c;
interview.ruleSetId = interviewRecord.Rule_Set_Id__c;
interview.group2Id = interviewRecord.Group2_Option_Id__c;
interview.group2Label = interviewRecord.Group_2_Option__c;
interview.group3Label = interviewRecord.Group3_Option__c;
interview.group3Id = interviewRecord.Group3_Option_Id__c;
interview.type = interviewRecord.Type__c;
interview.relationToMember = interviewRecord.Relation_To_Member__c;
interview.verbalAuthorizationConfirmed = interviewRecord.Verbal_Authorization_Confirmed__c;
interview.id = interviewRecord.Id;
interview.status = interviewRecord.Status__c;
interview.visibility = interviewRecord.Visibility__c == null ? 'Private' : interviewRecord.Visibility__c; //set default to private if visibility value doesn't exist, safer then public
if (interview.status != null && !interviewRecord.Interview_Question_Responses__r.isEmpty()) {
interview.interviewQuestionAndAnswers = new List<InterviewQuestionAndAnswer>();
for (
Interview_Question_Response__c interviewQuestionAndAnswer : interviewRecord.Interview_Question_Responses__r
                ) {
InterviewQuestionAndAnswer interviewQuestionAndAnswerObj = new InterviewQuestionAndAnswer();
interviewQuestionAndAnswerObj.id = interviewQuestionAndAnswer.Id;
interviewQuestionAndAnswerObj.question = interviewQuestionAndAnswer.Question_Text__c;
interviewQuestionAndAnswerObj.answer = interviewQuestionAndAnswer.Answer__c;
interviewQuestionAndAnswerObj.textAnswer = interviewQuestionAndAnswer.Answer__c;
if(interviewQuestionAndAnswer.Address_Answer__c != null){
interviewQuestionAndAnswerObj.addressAnswer = new InterviewQuestionAndAnswer.AddressAnswer();
interviewQuestionAndAnswerObj.addressAnswer.street = interviewQuestionAndAnswer.Address_Answer__Street__s;
interviewQuestionAndAnswerObj.addressAnswer.city = interviewQuestionAndAnswer.Address_Answer__City__s;
interviewQuestionAndAnswerObj.addressAnswer.state = interviewQuestionAndAnswer.Address_Answer__StateCode__s;
interviewQuestionAndAnswerObj.addressAnswer.zip = interviewQuestionAndAnswer.Address_Answer__PostalCode__s;
interviewQuestionAndAnswerObj.addressAnswer.country = interviewQuestionAndAnswer.Address_Answer__CountryCode__s;
                    }
interviewQuestionAndAnswerObj.checkboxAnswer = interviewQuestionAndAnswer.Checkbox_Answer__c;
interviewQuestionAndAnswerObj.dateAnswer = interviewQuestionAndAnswer.Date_Answer__c;
interviewQuestionAndAnswerObj.dateTimeAnswer = interviewQuestionAndAnswer.DateTime_Answer__c;
interviewQuestionAndAnswerObj.multiSelectAnswer = interviewQuestionAndAnswer.Multi_Select_Answer__c;
interviewQuestionAndAnswerObj.phoneAnswer = interviewQuestionAndAnswer.Phone_Answer__c;
interviewQuestionAndAnswerObj.picklistAnswer = interviewQuestionAndAnswer.Picklist_Answer__c;
interviewQuestionAndAnswerObj.serialNumber = String.valueof(interviewQuestionAndAnswer.Serial_Number__c);
interviewQuestionAndAnswerObj.questionId = interviewQuestionAndAnswer.Question_Id__c;
interview.interviewQuestionAndAnswers.add(interviewQuestionAndAnswerObj);
                }
            }
response = new LWCResponse(true, interview);
        } catch (Exception ex) {
Logger.exception(ex);
response = new LWCResponse(false, ex.getMessage());
        }
return response;
    }
    /**
     * @description : Deletes an Interview record and its related children (Question Responses, History).
     *                Tasks are preserved. Historical interviews cannot be deleted.
     * @author luke.vang@optum.com | 02-19-2026
     * @param interviewId
     * @return LWCResponse
     **/
@AuraEnabled
public static LWCResponse deleteInterview(String interviewId) {
LWCResponse resp = new LWCResponse(false, null);
try {
if (String.isBlank(interviewId)) {
throw new AuraHandledException('Interview Id is required.');
            }
// Query the interview and verify it is not historical
List<Interview__c> interviews = (List<Interview__c>) INSCRMUtils.checkFLS(
                [SELECT Id, Historical__c FROM Interview__c WHERE Id = :interviewId LIMIT 1],
AccessType.READABLE
            );
if (interviews.isEmpty()) {
throw new AuraHandledException('Interview not found.');
            }
if (interviews[0].Historical__c == true) {
throw new AuraHandledException('Cannot delete historical interviews.');
            }
// 1. Delete related Interview_Question_Response__c records
//    (this fires the before-delete trigger which creates History__c records)
deleteAllInterviewResponses(interviewId);
// 2. Delete all related History__c records (including any just created by the trigger)
if (INSCRMUtils.checkCRUD(Schema.SObjectType.History__c.getSObjectType(), CRUD.DELETABLE)) {
List<History__c> historyRecords = (List<History__c>) INSCRMUtils.checkFLS(
                    [SELECT Id FROM History__c WHERE Interview__c = :interviewId],
AccessType.READABLE
                );
if (!historyRecords.isEmpty()) {
delete historyRecords;
                }
            }
// 3. Delete the Interview record itself (Tasks are kept; their lookup nulls via SetNull)
if (INSCRMUtils.checkCRUD(Schema.SObjectType.Interview__c.getSObjectType(), CRUD.DELETABLE)) {
delete interviews[0];
            }
resp = new LWCResponse(true, 'Interview deleted successfully.');
        } catch (Exception ex) {
Logger.exception(ex);
resp = new LWCResponse(false, ex.getMessage());
        }
return resp;
    }
    /**
     * @description : delete the Interview Question Responses related to the Interview Id passed in the parameter
     * @author luke.vang@optum.com | 07-22-2024
     * @param interviewId
     **/
@AuraEnabled
public static void deleteAllInterviewResponses(String interviewId) {
if (INSCRMUtils.checkCRUD(Schema.SObjectType.Interview_Question_Response__c.getSObjectType(), CRUD.DELETABLE)) {
List<Interview_Question_Response__c> interviewQuestionResponses = (List<Interview_Question_Response__c>) INSCRMUtils.checkFLS(
                [
SELECT Id
FROM Interview_Question_Response__c
WHERE Interview__c = :interviewId
                ],
AccessType.READABLE
            );
if (!interviewQuestionResponses.isEmpty()) {
delete interviewQuestionResponses;
            }
        }
    }
    /**
     * @description : delete the Interview response related to the Id passed in the parameter
     * @author luke.vang@optum.com | 07-22-2024
     * @param id
     **/
@AuraEnabled
public static void deleteIndividualInterviewResponses(List<String> ids) {
if (INSCRMUtils.checkCRUD(Schema.SObjectType.Interview_Question_Response__c.getSObjectType(), CRUD.DELETABLE)) {
List<Interview_Question_Response__c> records = (List<Interview_Question_Response__c>) INSCRMUtils.checkFLS(
                [SELECT Id FROM Interview_Question_Response__c WHERE Id IN :ids],
AccessType.READABLE
            );
if (!records.isEmpty()) {
delete records;
            }
        }
    }
    /**
     * @description Calls Create Contact API
     * @author luke.vang@optum.com | 01-29-2025
     * @param oppId
     * @return LWCResponse
     **/
@AuraEnabled
public static LWCResponse createContactHistory(String oppId, String interviewId) {
LWCResponse response = new LWCResponse();
if (String.isBlank(oppId)) {
response.success = false;
response.data = 'Opportunity Id required.';
return response;
        }
Logger.start();
Logger.createLogsAtEnd = true;
Boolean exceptionCheck = false;
try {
List<Opportunity> opp = (List<Opportunity>) INSCRMUtils.checkFLS(
                [SELECT Id, AccountId, Account.Individual_Id__c FROM Opportunity WHERE Id = :oppId],
AccessType.READABLE
            );
List<Interview__c> interview = (List<Interview__c>) INSCRMUtils.checkFLS(
                [
SELECT
Id,
Type__c,
Relation_To_Member__c,
Visibility__c,
Status__c,
                        (
SELECT Id, Answer__c, Question_Text__c
FROM Interview_Question_Responses__r
                        )
FROM Interview__c
WHERE Id = :interviewId
                ],
AccessType.READABLE
            );
String accessToken = StarGate.getAccessToken();
HttpRestCallOut.headerMap.put('Authorization', 'Bearer ' + accessToken);
String ACCOUNT_ID = opp[0].AccountId;
String CONTACT_TYPE_DESC = interview[0].Type__c;
String CONTACT_SOURCE_DESC =  interview[0].Relation_To_Member__c;
String CONTACT_ACTION_DESC = 'WESB';
String CONTACT_ITEM_DESC = 'Application';
String CONTACT_NOTE = buildActionDescription(
interview[0].Status__c == 'Completed',
interview[0].Visibility__c != 'Public',
interview[0].Interview_Question_Responses__r,
interview[0].Relation_To_Member__c
            );
String CONTACT_REPRESENTATIVE = 'ISCRM';
CreateContactWrapper wrapper = new CreateContactWrapper(
ACCOUNT_ID,
CONTACT_TYPE_DESC,
CONTACT_SOURCE_DESC,
CONTACT_ACTION_DESC,
CONTACT_ITEM_DESC,
CONTACT_REPRESENTATIVE,
CONTACT_NOTE
            );
HttpRestCallOut.setBody(JSON.serialize(wrapper));
HttpResponse resp = HttpRestCallOut.makeRestApiCall_LogISCRMAErrorEnd(
'CreateContactHistory',
interview[0].Id,
'CreateContactHistory',
oppId
            );
response = LWCResponseHelper.buildLWCResponseNoRetry(resp);
        } catch (Exception ex) {
exceptionCheck = true;
Logger.apiException(ex);
response.success = false;
response.data = 'Unable to create contact history. ' + ex.getMessage();
        } finally {
//because we could be potentially being doing multiple api calls (access token refresh + employer summary)
//we need use the insertLogsAtEnd feature so logs are added to a collection then inserted
if (!exceptionCheck) {
Logger.apiLog();
            }
Logger.insertLogsAtEnd();
ISCRMLogger.insertLogsAtEnd();
        }
return response;
    }
    /**
     * @description builds request body for action description
     * @author luke.vang@optum.com | 03-06-2025
     * @param isPrivate
     * @param interviewId
     * @return String
     **/
public static String buildActionDescription(
Boolean completed,
Boolean isPrivate,
List<Interview_Question_Response__c> interviewQuestions,
String relationToMember
    ) {
String actionDescription = '';
if(isPrivate){
actionDescription = 'UW Activity';
        }else{
List<InterviewQuestionAndAnswer> interviewQuestionAndAnswerList = new List<InterviewQuestionAndAnswer>();
for (Interview_Question_Response__c questionResponse : interviewQuestions) {
actionDescription += questionResponse.Question_Text__c + ' ' + questionResponse.Answer__c + ',';
            }
actionDescription = actionDescription.removeEnd(',');
        }
return actionDescription;
    }
}
