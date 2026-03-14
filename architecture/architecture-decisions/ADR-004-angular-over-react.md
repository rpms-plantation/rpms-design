# ADR-004: Use Angular 18 for the Management Web Dashboard

- **Date**: 2026-03-14
- **Status**: Accepted
- **Deciders**: RPMS Architecture Team
- **Consulted**: Frontend development leads, plantation management stakeholders
- **Supersedes**: Initial React 18 recommendation from preliminary architecture review

## Context and Problem Statement

The Rubber Plantation Management System (RPMS) requires a web-based management dashboard serving estate managers, division conductors, and administrators. The dashboard is a complex enterprise application encompassing six domain modules (Plantation Field Records, Tree Tracking, Tapping Tasks, Workforce, Daily Activities, Attendance), each with rich data entry forms, real-time data streams (IoT sensor feeds, live tapper locations, attendance counts), spatial visualization (field boundaries, GPS routes, disease heatmaps), and analytical charts (yield trends, clone performance, attendance calendars).

This is not a simple marketing site or a content application. It is a multi-module enterprise operational platform with the following characteristics:

- **60+ domain entities** mapped from a PostgreSQL database schema that must be represented as TypeScript interfaces/models
- **Complex data entry forms** — worker registration (20+ fields with cross-field validation), attendance regularization (before/after state comparison), material usage logging (planned vs actual with variance calculation), leave applications with approval workflows
- **Real-time streaming** — WebSocket connections for live tapper GPS positions, IoT sensor feeds (temperature, rainfall, latex flow rates), attendance check-in events, and tapping task progress updates
- **Spatial visualization** — field boundary polygons (PostGIS), GPS route LineStrings, tree position Points, geofence zones, disease heatmaps overlaid on plantation maps
- **Six independently navigable modules** that will grow to 10+ in future phases (Financial, Processing, Supply Chain, Inventory, Sustainability, BI Portal)
- **Role-based access control** — integrated with Keycloak (OAuth2/OIDC) for TAPPER, SUPERVISOR, CONDUCTOR, MANAGER, and ADMIN role hierarchies
- **Offline resilience awareness** — the dashboard must degrade gracefully when backend services are temporarily unreachable (plantation environments have variable connectivity)
- **Team scalability** — the codebase must remain maintainable as the development team grows from 1-2 developers to 5-10+ across future phases

The frontend framework choice will be a foundational decision that persists for years and affects developer hiring, code maintainability, feature velocity, and long-term total cost of ownership.

## Decision Drivers

1. **Enterprise structure and long-term maintainability** — Framework must enforce consistent patterns as the team and codebase grow
2. **Complex form handling** — Extensive data entry with cross-field validation, dynamic form groups, and conditional fields
3. **Real-time data streaming** — Native support for WebSocket and server-sent events with composable stream processing
4. **TypeScript rigor** — Strong typing across 60+ domain entities to prevent runtime errors and improve refactoring confidence
5. **Spatial visualization** — Adequate mapping library ecosystem (Mapbox GL / Leaflet integration)
6. **Module isolation and lazy loading** — Clean boundaries between RPMS modules with on-demand loading
7. **Backend alignment** — Synergy with the Java/Kotlin backend team for shared mental models and patterns
8. **Developer availability** — Ability to hire frontend developers in target markets (South/Southeast Asia)
9. **Initial learning curve vs long-term productivity** — Trade-off between time-to-first-feature and sustained development velocity

## Considered Options

1. **Angular 18** — Google's full-featured, opinionated enterprise framework
2. **React 18** — Meta's UI library with ecosystem-assembled architecture
3. **Vue 3** — Progressive framework with middle-ground philosophy

## Decision Outcome

**Chosen option: Angular 18**, because it provides the strongest combination of built-in enterprise architecture, superior form handling, native real-time streaming (RxJS), and TypeScript-first design — all of which are critical requirements for the RPMS dashboard. The trade-off of a steeper initial learning curve is justified by the long-term maintainability gains for a system that will grow across multiple phases and team sizes.

### Confirmation

This decision will be confirmed successful if:
- The first two RPMS modules (Plantation + Tree) are delivered within the estimated timeline using Angular's module and routing patterns
- New developers onboarding to the project can contribute productive code within 2 weeks using Angular's established conventions
- Real-time features (live map, attendance feed) are implemented cleanly using RxJS Observables without requiring additional state management libraries
- Adding future-phase modules (Financial, Processing) requires creating new lazy-loaded Angular modules without modifying existing module code

## Pros and Cons of the Options

### Angular 18

Angular is a comprehensive, batteries-included framework maintained by Google. It provides a complete architecture out of the box: dependency injection, module system, routing with guards, HTTP interceptors, reactive forms, and RxJS integration. Angular 18 introduces signal-based reactivity alongside the existing zone-based change detection.

**Pros:**

- **Built-in module architecture** — Angular's NgModule system (and the newer standalone component approach) provides natural boundaries for each RPMS domain module. Each module (Plantation, Tree, Tapping, Workforce, Activity, Attendance) becomes a lazy-loaded Angular module with its own routing, components, and services. This structure is enforced by the framework, not left to team convention.
- **Reactive Forms are enterprise-grade** — Angular's `FormGroup`, `FormArray`, and `FormControl` with built-in validators, dynamic form generation, and cross-field validation are purpose-built for the kind of complex data entry RPMS requires. Worker registration, attendance regularization, and material usage forms all need dynamic field groups that React's ecosystem handles less natively.
- **RxJS is a first-class citizen** — Every Angular HTTP call returns an Observable. WebSocket connections, server-sent events, and real-time streams compose naturally with operators like `switchMap`, `combineLatest`, `debounceTime`, and `retry`. For RPMS's live tapper map, IoT sensor dashboard, and attendance event stream, RxJS eliminates the need for external state management libraries.
- **TypeScript from the ground up** — Angular was designed for TypeScript. Every API, tutorial, and pattern is TypeScript-native with no JavaScript legacy to navigate. For a system with 60+ domain entities, strict typing prevents entire categories of bugs and makes large-scale refactoring safe.
- **Dependency injection** — Angular's hierarchical DI system enables clean service architecture. API services, WebSocket services, and caching services are injectable, testable, and mockable by design. This aligns well with the backend team's familiarity with Spring's DI container.
- **HTTP interceptors** — Built-in interceptor pipeline for JWT token attachment (Keycloak), error handling, retry logic, and loading indicators. No third-party libraries needed.
- **Angular CLI** — Generates consistent boilerplate: `ng generate module workforce --route workforce --module app`, `ng generate component worker-profile`, `ng generate service workforce-api`. Every developer produces structurally identical code.
- **Consistent codestyle across team** — Angular's opinionated conventions mean two developers writing the same feature produce architecturally similar code. This is critical as the team grows beyond 2-3 people.
- **Long-term stability** — Angular follows a predictable 6-month major release cadence with documented migration paths. Google uses Angular internally (Google Cloud Console, Firebase Console), ensuring continued investment.

**Cons:**

- **Steeper initial learning curve** — Angular requires understanding modules, DI, decorators, RxJS operators, and the component lifecycle before becoming productive. Estimated 2-4 weeks for a developer new to Angular vs 1-2 weeks for React.
- **Larger initial bundle size** — Angular's core framework is ~65KB gzipped vs React's ~42KB. Mitigated by lazy loading (only the active module's code is loaded) and Angular's tree-shaking, but the base payload is heavier.
- **Smaller developer pool than React** — React has approximately 2-3× the number of developers globally. Angular developers are fewer but tend to be more experienced with enterprise patterns.
- **Spatial/mapping ecosystem is adequate, not leading** — `ngx-mapbox-gl` and `ngx-leaflet` work but receive updates less frequently than React's `react-map-gl`. For RPMS's mapping needs (field polygons, GPS routes, heatmaps), the Angular wrappers are sufficient but not best-in-class.
- **Verbosity** — Angular code tends to be more verbose than React equivalents. A simple component requires a decorator, class, template, and style file. Standalone components in Angular 18 reduce this but don't eliminate it.

### React 18

React is a UI library (not a framework) maintained by Meta. It provides component rendering and hooks, with architecture assembled from third-party libraries (React Router, Redux/Zustand, React Query, React Hook Form, etc.).

**Pros:**

- **Strongest spatial visualization ecosystem** — `react-map-gl` (Mapbox), `deck.gl` (Uber), and `react-leaflet` are the most actively maintained mapping libraries in the JavaScript ecosystem. For RPMS's spatial features, React has the richest set of options.
- **Recharts / Nivo / Victory** — Excellent charting libraries purpose-built for React. More options and more active development than Angular's `ngx-charts`.
- **Lower initial learning curve** — A developer can be productive with React in 1-2 weeks. Components are just functions, JSX is intuitive, and hooks provide a clean mental model.
- **Larger developer pool** — Approximately 2-3× more React developers globally. Easier to hire, more Stack Overflow answers, more tutorials.
- **Lighter core bundle** — ~42KB gzipped for React + ReactDOM. Combined with code splitting, initial load can be very lean.
- **Flexibility** — React doesn't prescribe architecture. Teams can choose the patterns that fit their specific needs.

**Cons:**

- **No built-in architecture** — React provides rendering only. For RPMS's 6+ module enterprise application, the team must select and integrate: a router (React Router or TanStack Router), state management (Redux Toolkit, Zustand, Jotai, or Context), form handling (React Hook Form or Formik), data fetching (React Query / SWR), and an HTTP client (Axios or Fetch). Each choice introduces a dependency and a debate.
- **Form handling is weaker** — React Hook Form is good but not equivalent to Angular Reactive Forms for complex, dynamic form structures with nested groups and arrays. RPMS's worker registration, material logging, and inspection checklist forms would require significantly more custom code.
- **Real-time streaming is manual** — WebSocket and SSE management in React requires custom hooks, `useEffect` cleanup logic, and careful handling of stale closures. There is no RxJS equivalent built into React's paradigm. Libraries like `rxjs` can be added, but they feel foreign in React's ecosystem.
- **TypeScript is supported, not native** — React was designed for JavaScript and later added TypeScript support. Some libraries have incomplete type definitions. Generics in JSX can be awkward. The experience is good but not as seamless as Angular's TypeScript-native design.
- **Consistency risk at scale** — React's flexibility becomes a liability when the team grows. Without enforced conventions, two React developers can produce architecturally different implementations of the same feature. For an enterprise system spanning 6+ modules, this creates maintenance burden over time.
- **Ecosystem churn** — React's ecosystem evolves rapidly. Libraries that are popular today (e.g., Redux → Redux Toolkit → Zustand → Jotai) may shift in 1-2 years, requiring migration effort.

### Vue 3

Vue is a progressive framework with the Composition API, offering a middle ground between Angular's structure and React's flexibility.

**Pros:**

- **Gentle learning curve** — Vue's template syntax and Composition API are intuitive. Single-file components (`.vue`) are self-contained and readable.
- **Good form handling** — VeeValidate and FormKit provide decent form capabilities, better than React's ecosystem though not as comprehensive as Angular Reactive Forms.
- **TypeScript support improving** — Vue 3 with `<script setup lang="ts">` provides good TypeScript support, though not as deeply integrated as Angular.
- **Pinia state management** — Clean, simple, and well-typed store management.

**Cons:**

- **Smallest enterprise adoption** — Vue is less common in enterprise applications, particularly in the Java/Spring Boot ecosystem. Finding Vue developers experienced with enterprise patterns is harder.
- **Weakest mapping/spatial ecosystem** — Mapping libraries for Vue (vue-mapbox, vue-leaflet) are the least actively maintained of the three frameworks.
- **Team alignment** — The backend team uses Java/Spring Boot, which philosophically aligns better with Angular's structured, DI-based approach than Vue's progressive enhancement model.
- **Smaller community for enterprise patterns** — Fewer resources, fewer enterprise-scale open-source examples, and fewer consultants available for complex Vue architectures.

## Decision Matrix

| Criterion (Weight) | Angular 18 | React 18 | Vue 3 |
|---|---|---|---|
| Enterprise structure (High) | ★★★★★ | ★★☆☆☆ | ★★★☆☆ |
| Complex forms (High) | ★★★★★ | ★★★☆☆ | ★★★★☆ |
| Real-time streaming (High) | ★★★★★ | ★★★☆☆ | ★★★☆☆ |
| TypeScript rigor (High) | ★★★★★ | ★★★★☆ | ★★★★☆ |
| Spatial/mapping (Medium) | ★★★☆☆ | ★★★★★ | ★★☆☆☆ |
| Module isolation (High) | ★★★★★ | ★★★☆☆ | ★★★★☆ |
| Backend team alignment (Medium) | ★★★★★ | ★★★☆☆ | ★★★☆☆ |
| Developer availability (Medium) | ★★★☆☆ | ★★★★★ | ★★☆☆☆ |
| Learning curve (Low) | ★★☆☆☆ | ★★★★★ | ★★★★★ |
| Long-term maintainability (High) | ★★★★★ | ★★★☆☆ | ★★★★☆ |
| **Weighted Score** | **Highest** | **Middle** | **Lowest** |

## Specific Technology Choices Within Angular

With the Angular decision made, the following sub-decisions are also recorded:

| Concern | Choice | Rationale |
|---|---|---|
| Mapping / Spatial | `ngx-mapbox-gl` | Best Angular Mapbox binding; supports field polygons, GPS routes, heatmaps |
| Charts / Analytics | `ngx-charts` + `ng2-charts` (Chart.js) | `ngx-charts` for common chart types, `ng2-charts` for specialized visualizations |
| UI Component Library | Angular Material (Material 3) | Google-maintained, consistent with Angular updates, accessible, themeable |
| State Management | RxJS + Angular Services (no NgRx) | For RPMS's architecture, injectable services with BehaviorSubject/ReplaySubject provide sufficient state management without the ceremony of NgRx. If complexity warrants it in future phases, NgRx can be introduced per-module without refactoring existing modules |
| HTTP Client | Angular HttpClient (built-in) | Native support for interceptors, typed responses, and Observable-based API |
| Auth | `angular-auth-oidc-client` | Mature Keycloak/OIDC integration library for Angular |
| Forms | Angular Reactive Forms (built-in) | No third-party form library needed |
| Testing | Jasmine + Karma (unit), Playwright (E2E) | Angular CLI default for unit tests, Playwright for cross-browser E2E |
| CSS Framework | Angular Material + custom SCSS | Material Design 3 components with plantation-branded theming |

## Consequences

### Positive

- Every RPMS module maps cleanly to a lazy-loaded Angular module with isolated routing, services, and components. Adding Phase 2 modules (Financial, Processing) requires creating new modules without touching existing code.
- Complex data entry forms for worker registration, attendance regularization, leave applications, inspection checklists, and material logging are handled natively by Reactive Forms with minimal custom code.
- Real-time features (live tapper map, IoT dashboard, attendance event feed) compose cleanly through RxJS Observable pipelines connected to WebSocket services.
- The backend team (Java/Spring Boot) shares a conceptual model with Angular (dependency injection, services, interceptors, module boundaries), reducing the mental gap between frontend and backend development.
- The Angular CLI generates consistent code structure, enabling a growing team to contribute without extensive style guide enforcement.
- TypeScript strictness across the entire codebase provides compile-time safety for 60+ domain entity interfaces and API service contracts.

### Negative

- New frontend developers unfamiliar with Angular will need 2-4 weeks of ramp-up time before becoming productive. This is mitigated by Angular's extensive official documentation, the Angular CLI's scaffolding, and the consistency of the codebase once learned.
- The spatial visualization layer (`ngx-mapbox-gl`) is adequate but may require custom wrapper components for advanced features like animated GPS route playback or 3D field terrain views. If these become critical in future phases, we can evaluate embedding raw Mapbox GL JS directly (Angular supports this via ElementRef).
- The developer hiring pool is smaller than React. This is mitigated by the fact that Angular developers in the target markets (Sri Lanka, India, Malaysia — rubber plantation regions) are available and tend to have enterprise Java background alignment.
- Initial bundle size is larger than a minimal React setup. This is mitigated by lazy loading (users only download the modules they access) and Angular's aggressive tree-shaking in production builds.

### Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Angular deprecates NgModules entirely | Medium | Low | Angular 18 supports both NgModules and standalone components. Migration is incremental, not breaking. |
| `ngx-mapbox-gl` becomes unmaintained | Low | Medium | Mapbox GL JS can be used directly via Angular's `ViewChild` + `ElementRef`. The wrapper is a convenience, not a dependency. |
| Team cannot find Angular developers | Low | Medium | Angular developers are well-represented in South/Southeast Asian markets. The structured nature of Angular also makes it easier to onboard backend Java developers to frontend work. |
| RxJS complexity overwhelms junior developers | Medium | Low | Establish a curated set of RxJS operators for the project (10-15 common operators) with usage examples. Avoid exotic operator chains. |

## Links

- **Related ADRs**: ADR-002 (Spring Boot vs Quarkus), ADR-005 (Kotlin Multiplatform over Flutter)
- **Design artifacts**: [`rpms-design/architecture/rpms_high_level_architecture.html`](../rpms_high_level_architecture.html) — Layer 3 (Mobile & Web Clients)
- **Angular 18 documentation**: https://angular.dev/
- **ngx-mapbox-gl**: https://github.com/Wykks/ngx-mapbox-gl
- **RPMS database schema**: [`rpms-design/database/`](../../database/) — 60+ entities that map to Angular TypeScript interfaces
