declare module "react" {
  const React: any;
  export default React;
  export type ReactNode = any;
  export type ComponentType<P = {}> = any;
  export type FC<P = {}> = any;
  export type ReactElement = any;
  export type MouseEvent<T = Element> = any;
  export type TouchEvent<T = Element> = any;
  export type FormEvent<T = Element> = any;
  export type ChangeEvent<T = Element> = any;
  export function useState<T>(initialState: T | (() => T)): [T, (newState: T | ((prevState: T) => T)) => void];
  export function useEffect(effect: () => void | (() => void), deps?: ReadonlyArray<any>): void;
  export function useRef<T>(initialValue?: T): { current: T };
  export function useCallback<T extends (...args: any[]) => any>(callback: T, deps: ReadonlyArray<any>): T;
  export function useMemo<T>(factory: () => T, deps: ReadonlyArray<any> | undefined): T;
}

declare module "react/jsx-runtime" {
  export const jsx: any;
  export const jsxs: any;
  export const Fragment: any;
}

declare module "next" {
  export interface Metadata {
    title?: string;
    description?: string;
    [key: string]: any;
  }
}

declare module "next/link" {
  const Link: any;
  export default Link;
}

declare module "next/navigation" {
  export const usePathname: () => string;
  export const useRouter: () => {
    push: (url: string) => void;
    replace: (url: string) => void;
    back: () => void;
    forward: () => void;
    refresh: () => void;
    prefetch: (url: string) => void;
  };
  export const useSearchParams: () => any;
  export const useParams: () => any;
}

declare module "next-auth/react" {
  export const useSession: () => {
    data: {
      user?: {
        name?: string;
        email?: string;
        role?: string;
        image?: string;
      };
      expires?: string;
    } | null;
    status: "authenticated" | "unauthenticated" | "loading";
  };
  export const signOut: (options?: any) => Promise<any>;
  export const signIn: (provider?: any, options?: any) => Promise<any>;
}

declare module "lucide-react" {
  export const [key: string]: any;
}
