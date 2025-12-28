## Phase 4 — Data Model Hardening + Social

14) `docs/data_improvement_1.md`
- Why now: atomic updates and schema clarity prevent race conditions and support scaling features.
- Dependencies: testing + (some) architecture groundwork.

15) `docs/social_improvement_1.md`
- Why now: improves correctness and UX for search/cancellation/idempotency.
- Dependencies: data improvements (normalized fields) + observability + permission coordinator.

## Phase 5 — AI Pipeline Reliability

16) `docs/ai_improvement_1.md`
- Why now: unifies duplicated generation logic and enforces validation-first outputs.
- Dependencies:
  - security decision (server-side proxy vs client keys)
  - data/persistence improvements
  - reliability fixes for conversation history

## Phase 6 — Performance + UI Polish

17) `docs/performance_improvement_1.md`
- Why now: caching improvements benefit from having observability in place so you can measure hit-rate/latency.

18) `docs/frontend_improvement_1.md`
- Why now: tackle UI consistency/accessibility after core correctness/navigation are stable.

19) `docs/onboarding_improvement_2.md`
- Why last: an interactive onboarding overlay depends on stable routing/navigation and consistent UI patterns.

## If You Only Do 5 Things
1. `docs/security_improvement_1.md`
2. `docs/privacy_improvement_1.md`
3. `docs/testing_improvement_1.md`
4. `docs/reliability_improvement_1.md`
5. `docs/onboarding_improvement_1.md`
