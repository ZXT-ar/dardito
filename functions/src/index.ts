import {setGlobalOptions} from "firebase-functions/v2";

import {region} from "./config.js";

setGlobalOptions({region, maxInstances: 20});

export {
  darditoChat,
  darditoChatPreproduction,
  health,
  publicSitemap,
  publicStoryImage,
  publicStoryPage,
  publicStories,
  publicCatalogs,
  submitStory,
  upsertKnowledge,
  upsertUserProfile,
  userAccessStatus,
  storyLikes,
  usageAnalytics,
} from "./channels/http.js";
export {
  activateEditorialAccess,
  adminGetDarditoParameters,
  adminGetCatalogs,
  adminGetInfrastructureStatus,
  adminGetKnowledge,
  adminGetUsageMetrics,
  adminGeneralReport,
  adminCreateResource,
  adminDeleteResource,
  adminDiscardResourceUpload,
  adminExtractDocumentStories,
  adminExportAuditReport,
  adminFinalizeResource,
  adminListAudit,
  adminListEditorialUsers,
  adminListKnowledge,
  adminListResources,
  adminListSubmissions,
  adminQueryAudit,
  adminRegisterSession,
  adminReviewSubmission,
  adminSaveCatalogs,
  adminSaveDarditoParameters,
  adminSaveKnowledge,
  adminSetEditorialAccess,
  adminTransitionKnowledge,
  adminUpdateResource,
} from "./channels/admin.js";

export {processWhatsAppInbound, whatsappWebhook} from "./channels/whatsapp.js";
