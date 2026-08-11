"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
  type User,
} from "firebase/auth";
import { auth, getCoachContextCallable } from "@/lib/firebase";
import { formatCallableError } from "@/lib/errors";
import type { CoachContextTeam, CoachRole } from "@/lib/types";

const ACTIVE_TEAM_STORAGE_KEY = "mindsetforge-coach:activeTeamId";

type AuthContextValue = {
  user: User | null;
  role: CoachRole | null;
  teams: CoachContextTeam[];
  activeTeamId: string | null;
  setActiveTeamId: (teamId: string) => void;
  loading: boolean;
  error: string | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  refresh: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

function readStoredActiveTeamId(): string | null {
  if (typeof window === "undefined") return null;
  try {
    return window.localStorage.getItem(ACTIVE_TEAM_STORAGE_KEY);
  } catch {
    return null;
  }
}

function writeStoredActiveTeamId(teamId: string): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(ACTIVE_TEAM_STORAGE_KEY, teamId);
  } catch {
    // Ignore storage failures (e.g. private browsing) — activeTeamId still
    // works for the current session, it just won't survive a reload.
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [role, setRole] = useState<CoachRole | null>(null);
  const [teams, setTeams] = useState<CoachContextTeam[]>([]);
  const [activeTeamId, setActiveTeamIdState] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadCoachContext = useCallback(async () => {
    setError(null);
    try {
      const result = await getCoachContextCallable({});
      const { role: nextRole, teams: nextTeams } = result.data;
      setRole(nextRole);
      setTeams(nextTeams);

      const stored = readStoredActiveTeamId();
      const validTeamIds = new Set(nextTeams.map((t) => t.teamId));
      if (stored && validTeamIds.has(stored)) {
        setActiveTeamIdState(stored);
      } else {
        const fallback = nextTeams[0]?.teamId ?? null;
        setActiveTeamIdState(fallback);
        if (fallback) writeStoredActiveTeamId(fallback);
      }
    } catch (err) {
      setRole(null);
      setTeams([]);
      setActiveTeamIdState(null);
      setError(formatCallableError(err, "Failed to load your coach account."));
    }
  }, []);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (nextUser) => {
      setUser(nextUser);
      if (!nextUser) {
        setRole(null);
        setTeams([]);
        setActiveTeamIdState(null);
        setError(null);
        setLoading(false);
        return;
      }

      await loadCoachContext();
      setLoading(false);
    });
    return unsub;
  }, [loadCoachContext]);

  const setActiveTeamId = useCallback((teamId: string) => {
    setActiveTeamIdState(teamId);
    writeStoredActiveTeamId(teamId);
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      user,
      role,
      teams,
      activeTeamId,
      setActiveTeamId,
      loading,
      error,
      async login(email, password) {
        await signInWithEmailAndPassword(auth, email, password);
      },
      async logout() {
        await signOut(auth);
      },
      async refresh() {
        await loadCoachContext();
      },
    }),
    [user, role, teams, activeTeamId, setActiveTeamId, loading, error, loadCoachContext],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
