import { FirebaseError } from "firebase/app";

/**
 * Turns a callable rejection into a human sentence for display in the UI.
 *
 * Generalized from the inline helper in mindsetforge-admin's
 * PostsPageClient.tsx, extended to cover every code the Phase 2 callables in
 * functions/src/coach.ts throw (see the plan's "Error codes the portal must
 * handle" section).
 */
export function formatCallableError(err: unknown, fallback = "Something went wrong. Please try again."): string {
  if (err instanceof FirebaseError) {
    switch (err.code) {
      case "functions/already-exists":
        return "This account already has a team. Log in instead of signing up again.";
      case "functions/failed-precondition":
        return "This invite is no longer available. It may have already been accepted or revoked.";
      case "functions/permission-denied":
        return "You don't have access to do that. Check that you're signed in with the right account.";
      case "functions/unauthenticated":
        return "You need to be signed in to do that.";
      case "functions/resource-exhausted":
        return "Too many requests right now. Please wait a moment and try again.";
      case "functions/not-found":
        return err.message || "We couldn't find that.";
      case "functions/invalid-argument":
        return err.message || "Some of the information provided isn't valid.";
      case "functions/internal":
        return err.message || "Something went wrong on our end. Please try again.";
      case "functions/deadline-exceeded":
        return "That took too long to complete. Please try again.";
      default:
        return err.message || fallback;
    }
  }
  if (err instanceof Error) {
    return err.message || fallback;
  }
  return fallback;
}

/**
 * Layers friendlier text on top of formatCallableError for Firebase Auth
 * error codes (`auth/*`), which formatCallableError does not cover since it
 * is scoped to the `functions/*` codes thrown by the coach callables. Used on
 * the signup and join pages, which call `createUserWithEmailAndPassword`
 * directly before ever touching a callable.
 */
export function formatAuthError(err: unknown, fallback = "Something went wrong. Please try again."): string {
  if (err instanceof FirebaseError) {
    switch (err.code) {
      case "auth/email-already-in-use":
        return "An account with that email already exists. Try signing in instead.";
      case "auth/invalid-email":
        return "That email address doesn't look right.";
      case "auth/weak-password":
        return "Please choose a stronger password.";
      case "auth/wrong-password":
      case "auth/invalid-credential":
        return "That email and password don't match. Please try again.";
      case "auth/user-not-found":
        return "No account found with that email.";
      case "auth/too-many-requests":
        return "Too many attempts. Please wait a moment and try again.";
      default:
        break;
    }
  }
  return formatCallableError(err, fallback);
}
