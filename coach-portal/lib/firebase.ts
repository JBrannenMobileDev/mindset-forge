import { initializeApp, getApps } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getFunctions, httpsCallable } from "firebase/functions";
import type {
  AcceptTeamInviteRequest,
  AcceptTeamInviteResponse,
  AddManualPromptRequest,
  AddManualPromptResponse,
  AssignTeamPromptRequest,
  AssignTeamPromptResponse,
  CreatePlayerInvitesRequest,
  CreatePlayerInvitesResponse,
  DeletePromptRequest,
  DeletePromptResponse,
  GenerateTeamPromptsRequest,
  GenerateTeamPromptsResponse,
  GenerateTeamReportRequest,
  GenerateTeamReportResponse,
  GetCoachContextRequest,
  GetCoachContextResponse,
  GetTeamInviteInfoRequest,
  GetTeamInviteInfoResponse,
  InitializeCoachAccountRequest,
  InitializeCoachAccountResponse,
  RemovePlayerRequest,
  RemovePlayerResponse,
  UnassignTeamPromptRequest,
  UnassignTeamPromptResponse,
  UpdateTeamSettingsRequest,
  UpdateTeamSettingsResponse,
} from "@/lib/types";

// Same Firebase project as the Flutter app and the admin console
// (mindsetforge-ai). These values are public by design for web clients.
const firebaseConfig = {
  apiKey: "AIzaSyB9Qk-BgU0LKcOCFFlFdvvfbtd5NJevMEA",
  authDomain: "mindsetforge-ai.firebaseapp.com",
  projectId: "mindsetforge-ai",
  storageBucket: "mindsetforge-ai.firebasestorage.app",
  messagingSenderId: "107289472326",
  appId: "1:107289472326:web:99bd001472c6f5b6408947",
};

const app = getApps().length > 0 ? getApps()[0]! : initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const db = getFirestore(app);
export const functions = getFunctions(app, "us-central1");

/** AI callables (generateTeamPrompts, generateTeamReport) make a Claude call server-side. */
const AI_CALLABLE_TIMEOUT_MS = 300_000;

export const initializeCoachAccountCallable = httpsCallable<
  InitializeCoachAccountRequest,
  InitializeCoachAccountResponse
>(functions, "initializeCoachAccount");

export const getCoachContextCallable = httpsCallable<
  GetCoachContextRequest,
  GetCoachContextResponse
>(functions, "getCoachContext");

export const createPlayerInvitesCallable = httpsCallable<
  CreatePlayerInvitesRequest,
  CreatePlayerInvitesResponse
>(functions, "createPlayerInvites");

export const getTeamInviteInfoCallable = httpsCallable<
  GetTeamInviteInfoRequest,
  GetTeamInviteInfoResponse
>(functions, "getTeamInviteInfo");

export const acceptTeamInviteCallable = httpsCallable<
  AcceptTeamInviteRequest,
  AcceptTeamInviteResponse
>(functions, "acceptTeamInvite");

export const generateTeamPromptsCallable = httpsCallable<
  GenerateTeamPromptsRequest,
  GenerateTeamPromptsResponse
>(functions, "generateTeamPrompts", { timeout: AI_CALLABLE_TIMEOUT_MS });

export const addManualPromptCallable = httpsCallable<
  AddManualPromptRequest,
  AddManualPromptResponse
>(functions, "addManualPrompt");

export const deletePromptCallable = httpsCallable<
  DeletePromptRequest,
  DeletePromptResponse
>(functions, "deletePrompt");

export const assignTeamPromptCallable = httpsCallable<
  AssignTeamPromptRequest,
  AssignTeamPromptResponse
>(functions, "assignTeamPrompt");

export const unassignTeamPromptCallable = httpsCallable<
  UnassignTeamPromptRequest,
  UnassignTeamPromptResponse
>(functions, "unassignTeamPrompt");

export const removePlayerCallable = httpsCallable<
  RemovePlayerRequest,
  RemovePlayerResponse
>(functions, "removePlayer");

export const updateTeamSettingsCallable = httpsCallable<
  UpdateTeamSettingsRequest,
  UpdateTeamSettingsResponse
>(functions, "updateTeamSettings");

export const generateTeamReportCallable = httpsCallable<
  GenerateTeamReportRequest,
  GenerateTeamReportResponse
>(functions, "generateTeamReport", { timeout: AI_CALLABLE_TIMEOUT_MS });
