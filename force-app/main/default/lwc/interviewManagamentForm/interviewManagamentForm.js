import { LightningElement, wire, api } from 'lwc';
import { getRecord } from "lightning/uiRecordApi";
import LightningConfirm from 'lightning/confirm';
import { RefreshEvent } from 'lightning/refresh';
import { handleSuccessToast, generateId, getIsReadOnly } from 'c/utilities';
import interviewManagementModal from 'c/interviewManagementModal';
import createContactHistory from '@salesforce/apex/InterviewManagementController.createContactHistory';
import resetInterviewToInProgress from '@salesforce/apex/InterviewManagementController.resetInterviewToInProgress';
import getRuleSet from '@salesforce/apex/InterviewManagementController.getRuleSet';
import getGroup2Options from '@salesforce/apex/InterviewManagementController.getGroup2Options';
import getGroup3Options from '@salesforce/apex/InterviewManagementController.getGroup3Options';
import getInterviewQuestions from '@salesforce/apex/InterviewManagementController.getInterviewQuestions';
import saveInterview from '@salesforce/apex/InterviewManagementController.saveInterview';
import getInterview from '@salesforce/apex/InterviewManagementController.getInterview';
import INTERVIEW_CLOSING from '@salesforce/label/c.Interview_Closing';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import INTERVIEW_OBJECT from "@salesforce/schema/Interview__c";
import TYPE from '@salesforce/schema/Interview__c.Type__c';
import RELATION_TO_MEMBER from '@salesforce/schema/Interview__c.Relation_to_Member__c';
export default class InterviewManagamentForm extends LightningElement {
    @api opportunityRecordId;
    @api caseRecordId;
    @api accountRecordId;
    @api interviewRecordId;
    @api displayForm = false;
group1options = [];
group2options = [];
group3options = [];
selectedGroup1Option;
selectedGroup1Label;
selectedGroup2Option;
selectedGroup2Label;
selectedGroup3Option;
selectedGroup3Label;
interviewQuestions;
oppRuleSetName;
interview = this.defaultInterview;
loading = false;
interviewClosingLabel = INTERVIEW_CLOSING;
isReadOnlyAccess = true;
hasError = false;
interviewResponseIdsToDelete = [];
deleteAllQuestionAndResponses = false;
visible = 'Private';
interviewInfo;
interviewDefaultRecordTypeId;
typeOptions;
relationToMemberOptions;
    @wire(getObjectInfo, { objectApiName: INTERVIEW_OBJECT })
handleGetInterviewInfo({ error, data }) {
if (data) {
this.interviewDefaultRecordTypeId = data.defaultRecordTypeId;
        } else if (error) {
console.error(error);
        }
    }
    @wire(getPicklistValues, {
recordTypeId: "$interviewDefaultRecordTypeId",
fieldApiName: TYPE
    })
getTypePicklsiValues1({ error, data }) {
if (data) {
this.typeOptions = data.values;
        } else if (error) {
console.error(error);
        }
    }
    @wire(getPicklistValues, {
recordTypeId: "$interviewDefaultRecordTypeId",
fieldApiName: RELATION_TO_MEMBER
    })
getTypePicklsiValues2({ error, data }) {
if (data) {
this.relationToMemberOptions = data.values;
        } else if (error) {
console.error(error);
        }
    }
    @wire(getRecord, { recordId: "$interviewRecordId", fields: ['Interview__c.Id'] })
async wiredInterview({ error, data }) {
if (data) {
this.loading = true;
await this.handleGetInterview();
        } else if (error) {
console.error(error);
this.handleError(error);
        }
    }
    @wire(getRecord, { recordId: "$caseRecordId", fields: ['Case.Rule_Set__c'] })
async wireOpp({ error, data }) {
if (data) {
this.loading = true;
this.oppRuleSetName = data?.fields?.Rule_Set__c?.value;
if (!this.oppRuleSetName) {
this.template.querySelector('c-error-notifier').setError('Case Rule Set is not defined');
this.hasError = true;
this.loading = false;
return;
            }
this.isReadOnlyAccess = await getIsReadOnly('Interview__c');
this.setOppIdOnInterview();
await this.handleGetRuleSet();
        } else if (error) {
console.error(error);
        }
    }
handleChange(event) {
let interview = JSON.parse(JSON.stringify(this.interview));
if (event.target.dataset.id === 'combo-type') {
interview.type = event.target.value;
        } else {
interview.relationToMember = event.target.value;
        }
this.interview = interview;
    }
async handleGetInterview() {
try {
this.loading = true;
const result = await getInterview({ recordId: this.interviewRecordId });
if (result.success) {
this.interview = result.data;
if (this.interview?.type) {
this.template.querySelector('[data-id="combo-type"]').value = this.interview.type;
                }
if (this.interview?.relationToMember) {
this.template.querySelector('[data-id="combo-rel-to-member"]').value = this.interview.relationToMember;
                }
this.visible = this.interview.visibility;
this.selectedGroup1Option = this.interview.ruleSetId;
this.selectedGroup2Option = this.interview.group2Id;
this.selectedGroup3Option = this.interview.group3Id;
await this.handleGetOption2();
this.selectedGroup1Label = this.findGroup1LabelById(this.selectedGroup1Option);
this.selectedGroup2Label = this.findGroup2LabelById(this.selectedGroup2Option);
const hasDependentGroup3 = this.hasDependentGroup3(this.selectedGroup2Option);
if (hasDependentGroup3) {
await this.handleGetOption3();
this.selectedGroup3Label = this.findGroup3LabelById(this.selectedGroup3Option);
                }
this.interviewQuestions = this.interview.interviewQuestionAndAnswers;
const interviewQuestions = JSON.parse(JSON.stringify(this.interviewQuestions));
interviewQuestions.forEach(question => {
const answer = this.interview.interviewQuestionAndAnswers.find(a => a.questionId == question.Id);
if (answer) {
question.answer = answer.answer;
                    }
                });
this.interviewQuestions = interviewQuestions;
            } else if (result?.success === false) {
console.error(result.data);
this.handleError(result.data);
            }
        } catch (error) {
console.error(error);
this.handleError(error);
        } finally {
this.loading = false;
        }
    }
async handleGetRuleSet() {
try {
this.loading = true;
const result = await getRuleSet({ ruleSetName: this.oppRuleSetName, recordId: this.interviewRecordId });
if (result?.success) {
this.group1options = result.data;
if (this.group1options.length == 1) {
this.selectedGroup1Option = this.group1options[0].value;
this.selectedGroup1Label = this.group1options[0].label;
this.setRuleSetOnInterview();
// FIX: await handleGetOption2 to prevent loading state race condition
await this.handleGetOption2();
                }
            } else if (result?.success === false) {
this.handleError(result.data);
console.error(result.data);
            }
        } catch (error) {
console.error(error);
        } finally {
this.loading = false;
        }
    }
async handleGetOption2() {
try {
this.loading = true;
const result = await getGroup2Options({ ruleSetId: this.selectedGroup1Option, recordId: this.interviewRecordId });
if (result.success) {
// --- NEW: move "Free Form" to the first position ---
const options = Array.isArray(result.data) ? [...result.data] : [];
const freeIdx = options.findIndex(
o => (o.label || '').trim().toLowerCase() === 'free form'
                );
if (freeIdx > -1) {
const [freeForm] = options.splice(freeIdx, 1);
options.unshift(freeForm);
                }
this.group2options = options;
// ----------------------------------------------------
            } else if (result?.success === false) {
console.error(result.data);
this.handleError(result.data);
            }
        } catch (error) {
console.error(error);
this.handleError(error);
        } finally {
this.loading = false;
        }
    }
async handleGetOption3() {
try {
this.loading = true;
const result = await getGroup3Options({ group2Id: this.selectedGroup2Option, ruleSetId: this.selectedGroup1Option, recordId: this.interviewRecordId });
if (result.success) {
this.group3options = result.data;
            } else if (result?.success === false) {
console.error(result.data);
this.handleError(result.data);
            }
        } catch (error) {
console.error(error);
this.handleError(error);
        } finally {
this.loading = false;
        }
    }
async handleGetInterviewQuestions() {
try {
this.loading = true;
const result = await getInterviewQuestions({ group2Id: this.selectedGroup2Option, group3Id: this.selectedGroup3Option, recordId: this.interviewRecordId });
if (result.success) {
result.data.forEach(q => {
q.question = q.Question_Text__c;
q.questionId = q.Id;
                });
this.interviewQuestions = result.data;
if (!this.interview?.interviewQuestionAndAnswers || this.interview?.interviewQuestionAndAnswers.length == 0) {
this.setDefaultInterviewQuestionsAndAnswers();
                }
            } else if (result?.success === false) {
console.error(result.data);
this.handleError(result.data);
            }
        } catch (error) {
console.error(error);
this.handleError(error);
        } finally {
this.loading = false;
        }
    }
setDefaultInterviewQuestionsAndAnswers() {
let interviewQuestions = JSON.parse(JSON.stringify(this.interviewQuestions));
let interviewQuestionsAndAnswers = [];
interviewQuestions.forEach(q => {
interviewQuestionsAndAnswers.push({ questionId: q.questionId, question: q.question, answer: '', serialNumber: q.Serial_Number__c });
        });
this.setInterviewQuestionsOnInterview(interviewQuestionsAndAnswers);
    }
handleGroup1Change(event) {
this.clearGroup2Option();
    }
async handleGroup2Change(event) {
const group2Value = event.target.value;
const group2Label = this.findGroup2LabelById(group2Value);
this.handleDeleteAllQuestionResponses();
this.selectedGroup2Option = group2Value;
this.selectedGroup2Label = group2Label;
this.template.querySelector('[data-id="group2"]').value = this.selectedGroup2Option;
const hasDependentGroup3 = this.hasDependentGroup3(group2Value);
this.setGroup2OnInterview();
this.clearGroup3Option();
if (this.selectedGroup2Option && this.selectedGroup2Label != 'Free Form' && hasDependentGroup3) {
this.handleGetOption3();
        } else if (this.selectedGroup2Option && this.selectedGroup2Label != 'Free Form' && !hasDependentGroup3) {
this.handleGetInterviewQuestions();
        } else if (this.selectedGroup2Label == 'Free Form') {
this.interviewQuestions = this.defaultFreeFormQuestion;
        }
    }
async handleGroup3Change(event) {
const group3Value = event.target.value;
const group3Label = this.findGroup3LabelById(group3Value);
this.handleDeleteAllQuestionResponses();
this.selectedGroup3Option = group3Value;
this.selectedGroup3Label = group3Label;
this.setGroup3OnInterview();
this.handleGetInterviewQuestions();
    }
handleAnswerChange(event) {
const interviewQuestions = JSON.parse(JSON.stringify(this.interviewQuestions));
const value = event.target.value.trim();
const question = event.target.dataset.question;
const serialNumber = event.target.dataset.serial;
const questionId = event.target.dataset.id;
interviewQuestions.find(q => q.Id == questionId).answer = value;
const questionAnswerRecId = this.interview.interviewQuestionAndAnswers.find(q => q?.questionId == questionId)?.id;
this.interviewQuestions = interviewQuestions;
const questionAndAnswer = { 'id': questionAnswerRecId, 'answer': value, 'question': question, 'questionId': questionId, 'serialNumber': serialNumber };
this.handleAddAnswerAndQuestions(questionAndAnswer);
    }
handleFreeFormItemUpdate(event) {
const freeFormItem = { ...event.detail };
console.log('Free Form Item Update:', JSON.stringify(freeFormItem));
console.log('Current Interview Questions:', JSON.stringify( this.interview));
const questionAnswerRecId = this.interview.interviewQuestionAndAnswers.find(q => q?.questionId == freeFormItem.questionId)?.id;
console.log('tt', questionAnswerRecId);
freeFormItem.id = questionAnswerRecId;
this.handleAddAnswerAndQuestions(freeFormItem);
    }
handleAddAnswerAndQuestions(entry) {
const interviewQuestionAndAnswers = JSON.parse(JSON.stringify(this.interview.interviewQuestionAndAnswers));
const index = interviewQuestionAndAnswers.findIndex(i => i.questionId == entry.questionId);
if (index > -1) {
interviewQuestionAndAnswers[index] = entry;
        } else {
interviewQuestionAndAnswers.push(entry);
        }
this.setInterviewQuestionsOnInterview(interviewQuestionAndAnswers);
    }
handleAddFreeFormQuestion() {
const interviewQuestions = JSON.parse(JSON.stringify(this.interviewQuestions));
const freeFormItem = { questionId: generateId(21), question: '', answer: '' };
interviewQuestions.push(freeFormItem);
this.interviewQuestions = interviewQuestions;
this.handleAddAnswerAndQuestions(freeFormItem);
    }
async handleRemoveFreeFormQuestion(event) {
const interviewQuestions = JSON.parse(JSON.stringify(this.interviewQuestions));
const interview = JSON.parse(JSON.stringify(this.interview));
const questionId = event.detail;
const sfQuestionAnswerRecId = this.interview.interviewQuestionAndAnswers.find(q => q?.questionId == questionId)?.id;
const filteredFreeFormQuestions = interviewQuestions.filter(q => q.questionId != questionId);
const fileredInterview = interview.interviewQuestionAndAnswers.filter(q => q.questionId != questionId);
if (sfQuestionAnswerRecId) {
this.interviewResponseIdsToDelete.push(sfQuestionAnswerRecId);
        }
this.interviewQuestions = filteredFreeFormQuestions;
this.interview.interviewQuestionAndAnswers = fileredInterview;
    }
async handleCancel(event) {
const result = !this.isReadOnly ? await this.triggerUnsavedWarning() : true;
if (result) {
this.clearForm();
this.dispatchEvent(new CustomEvent('cancel'));
        }
    }
async handleSubmit(event) {
// Validate Type and Relation to Member are required for Submit
if (!this.interview?.type || !this.interview?.relationToMember) {
this.template.querySelector('c-error-notifier').showErrorToast('Type and Relation to Member are required to submit an interview.');
return;
        }
if (!this.validateForm()) {
return;
        }
const result = await this.triggerConfirmSubmit();
if (result.action == 'okay') {
await this.handleSave(event, true, result.visibility);
        }
    }
async handleSave(event, isSubmit = false, visibility) {
try {
this.loading = true;
let successContactHistory = false;
// Only validate Type and Relation to Member for Submit, not for Save
if (isSubmit) {
if (!this.template.querySelector('[data-id="combo-type"]').reportValidity() || !this.template.querySelector('[data-id="combo-rel-to-member"]').reportValidity()) {
this.loading = false;
return;
                }
            }
if (!this.validateForm()) {
return;
            }
const interview = JSON.parse(JSON.stringify(this.interview));
interview.visibility = visibility;
interview.caseId = this.caseRecordId;
interview.accountId = this.accountRecordId;
interview.status = isSubmit && this.formCompleted() ? 'Completed' : 'In Progress';
const result = await saveInterview({ payload: JSON.stringify(interview), deleteAllQuestionAndResponses: this.deleteAllQuestionAndResponses, interviewResponseIdsToDelete: this.interviewResponseIdsToDelete });
if (result.success) {
this.loading = false;
if (!this.interviewRecordId) {
this.interviewRecordId = result.data;
                }
this.interviewResponseIdsToDelete = [];
this.deleteAllQuestionAndResponses = false;
this.dispatchEvent(new RefreshEvent());
if (isSubmit) {
successContactHistory = await this.handleCreateContactHistory(isSubmit);
if (!successContactHistory) {
//if contact history creation was not successful, set the interview status back to 'In Progress'
if (isSubmit) {
await resetInterviewToInProgress({ recordId: this.interviewRecordId });
                        }
handleSuccessToast('Interview saved successfully');
await this.handleGetInterview();
return;
                    }
                }
if (isSubmit) {
handleSuccessToast('Interview submitted successfully');
this.clearForm();
this.dispatchEvent(new CustomEvent('cancel'));
                } else {
handleSuccessToast('Interview saved successfully');
this.clearForm();
this.dispatchEvent(new CustomEvent('cancel'));
                }
            } else if (result?.success === false) {
console.error(result.data);
this.handleError(result.data);
            }
        } catch (error) {
console.error(error);
this.handleError(error);
        } finally {
this.loading = false;
        }
    }
async handleCreateContactHistory(isSubmit) {
this.loading = true;
let success = false;
try {
let result = await createContactHistory({ oppId: this.opportunityRecordId, interviewId: this.interviewRecordId });
if (result.success) {
handleSuccessToast('Contact History Record created Successfully');
success = true;
            } else if (result?.success === false) {
console.error(result.data);
this.handleError(result.data);
            }
        } catch (error) {
console.error(error);
this.handleError(error);
        } finally {
this.loading = false;
        }
return success;
    }
setOppIdOnInterview() {
this.setInterviewAttribute('opportunityId', this.opportunityRecordId);
    }
setRuleSetOnInterview() {
this.setInterviewAttribute('ruleSetId', this.selectedGroup1Option);
this.setInterviewAttribute('ruleSetLabel', this.selectedGroup1Label)
    }
setGroup2OnInterview() {
this.setInterviewAttribute('group2Id', this.selectedGroup2Option);
this.setInterviewAttribute('group2Label', this.selectedGroup2Label);
    }
setGroup3OnInterview() {
this.setInterviewAttribute('group3Id', this.selectedGroup3Option);
this.setInterviewAttribute('group3Label', this.selectedGroup3Label);
    }
setInterviewQuestionsOnInterview(interviewQuestionAndAnswers) {
this.setInterviewAttribute('interviewQuestionAndAnswers', interviewQuestionAndAnswers);
    }
setInterviewAttribute(attribute, value) {
const interview = JSON.parse(JSON.stringify(this.interview));
attribute = String(attribute);
interview[attribute] = value;
this.interview = interview;
    }
clearForm() {
this.opportunityRecordId = null;
this.interviewRecordId = null;
this.displayForm = false;
this.group1options = [];
this.group2options = [];
this.group3options = [];
this.selectedGroup1Option = null;
this.selectedGroup2Option = null;
this.selectedGroup3Option = null;
this.interviewQuestions = null;
this.oppRuleSetName = null;
this.interview = this.defaultInterview;
this.deleteAllQuestionAndResponses = false;
this.interviewResponseIdsToDelete = [];
this.loading = false;
    }
clearGroup2Option() {
this.group2options = [];
this.selectedGroup2Option = '';
this.selectedGroup2Label = '';
this.setGroup2OnInterview();
this.clearGroup3Option();
    }
clearGroup3Option() {
this.group3options = [];
this.selectedGroup3Option = '';
this.selectedGroup3Label = '';
this.interviewQuestions = [];
this.setGroup3OnInterview();
    }
async handleDeleteAllQuestionResponses() {
const interview = JSON.parse(JSON.stringify(this.interview));
interview.interviewQuestionAndAnswers = [];
this.interview = interview;
this.deleteAllQuestionAndResponses = true;
    }
async triggerUnsavedWarning() {
const result = await LightningConfirm.open({
message: 'Navigating away from this page may result in the loss of any unsaved changes. If you have already saved your changes, you can ignore this warning. Do you want to proceed?',
theme: 'warning',
label: 'Warning: Potential Unsaved Changes',
        });
return result;
    }
async triggerConfirmSubmit() {
const result = await interviewManagementModal.open({
size: 'small',
description: 'Interview Submission Confirmation.',
content: this.interview.visibility
        });
return result;
    }
findGroup1LabelById(id) {
if (!this.group1options || this.group1options.length == 0) return;
return this.group1options.find(o => o.value == id).label;
    }
findGroup2LabelById(id) {
if (!this.group2options || this.group2options.length == 0) return;
return this.group2options.find(o => o.value == id).label;
    }
findGroup3LabelById(id) {
if (!this.group3options || this.group3options.length == 0) return;
return this.group3options.find(o => o.value == id).label;
    }
hasDependentGroup3(group2Value) {
if (!this.group2options) return;
const option = this.group2options.find(o => o.value == group2Value);
if (!option) return false;
return option.data.Has_Dependency__c;
    }
handleError(error) {
const notifier = this.template.querySelector('c-error-notifier');
if (notifier) {
notifier.showErrorToast(error);
        }
this.loading = false;
    }
formCompleted() {
const questionFields = [];
const answerFields = [];
let completed = false;
this.template.querySelectorAll('c-interview-management-free-form-item').forEach(element => {
questionFields.push(element.getQuestionField());
answerFields.push(element.getAnswerField());
        });
completed = questionFields.every(element => element.value && element?.value?.trim()) && answerFields.every(element => element.value && element?.value?.trim());
return completed;
    }
validateForm() {
let valid = true;
const questionFields = [];
const answerFields = [];
this.template.querySelectorAll('c-interview-management-free-form-item').forEach(element => {
questionFields.push(element.getQuestionField());
answerFields.push(element.getAnswerField());
        });
let allQuestionsFilled = questionFields.every(element => element.value && element?.value?.trim())
this.template.querySelectorAll('c-interview-management-free-form-item').forEach(element => {
element.validateQuestionField(true);
        });
if (!allQuestionsFilled) {
this.template.querySelectorAll('c-interview-management-free-form-item').forEach(element => {
if (!element.getQuestionField()?.value) {
element.validateQuestionField(false);
                }
            });
valid = false;
        }
return valid;
    }
handleToggle(event) {
this.visible = event.target.checked ? 'Public' : 'Private';
    }
get disableSubmit() {
return this.isReadOnly || !this.interviewQuestions || this.loading || !this.interview?.type || !this.interview?.relationToMember;
    }
get disableSave() {
return this.isReadOnly || !this.interviewQuestions || this.loading;
    }
get isReadOnly() {
return (this.interview.status == 'Completed' || this.isReadOnlyAccess) && this.interview.id;
    }
get defaultFreeFormQuestion() {
return [{ question: '', answer: '', questionId: generateId(21) }];
    }
get isFreeForm() {
return this.selectedGroup2Label == 'Free Form'
    }
get isGroup1Disabled() {
return this.group1options.length == 0 || this.isReadOnly;
    }
get isGroup2Disabled() {
return this.group2options.length == 0 || this.isReadOnly;
    }
get isGroup3Disabled() {
return this.group3options.length == 0 || this.isReadOnly;
    }
get isGroup3Required() {
return !this.isGroup3Disabled;
    }
get freeFormQuestionLength() {
return this.interviewQuestions && this.interviewQuestions.length ? this.interviewQuestions.length : 0;
    }
get defaultInterview() {
return { id: '', opportunityId: '', ruleSetLabel: '', ruleSetId: '', group2Id: '', group2Label: '', group3Id: '', group3Label: '', interviewQuestionAndAnswers: [], status: '' };
    }
get checked() {
return this.visible == 'Public';
    }
get displayInterviewQuestions() {
return !this.isReadOnly || this.checked;
    }
get toggleDisabled() {
return this.interview.visibility === 'Public';
    }
}
