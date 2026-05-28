# Framework QA triage register

Bugs filed against `~/code/fraiseql` during phases 00–08. Triaged in phase 09 (`personas.md § Framework Bug-Fixer`).

Format: one row per bug. Update the **Triage** column in phase 09; do not edit other columns retroactively.

| ID | Filed in phase / cycle | Issue URL | Severity (blocker / regression / qol) | Affects page(s) | Repro script | Workaround in docs? | Triage (fix-now / accept-limitation / wrong-as-filed) | Resolution PR |
|----|------------------------|-----------|---------------------------------------|-----------------|--------------|--------------------|-------------------------------------------------------|---------------|
| FW-1 | Phase 00 / Cycle 3 | https://github.com/fraiseql/fraiseql/issues/326 | qol | (future) `concepts/storage`, `guides/storage-backends` | `scripts/docs-test/lib/storage-smoke.sh` exercises sidecars; the FraiseQL server cannot reach Azurite/fake-gcs through configuration | Pending — overlays `configs/overlays/storage-azure.toml` and `storage-gcs.toml` document the limitation in their leading comment block; Cycle 5's smoke covers only the S3 backend end-to-end | _(open)_ | _(open)_ |

---

## Phase 09 triage threshold (G3)

The severity threshold above which phase 09 must close all items before phase 10 starts is **human gate G3**. Default proposal (subject to G3 confirmation): **blocker** and **regression** must be closed-by-fix or closed-as-wrong. **qol** may remain open as accepted-limitation with a `## Known issues` block on the affected page.

When phase 09 opens, the Bug-Finder persona writes a G3 proposal to `handoff.md` and stops for human input.
