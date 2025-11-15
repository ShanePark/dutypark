# TODO Attachments

### 1. Frontend Refactoring

- [x] Extract the overlapping Schedule/TODO upload + viewer logic into a shared JS helper module to remove duplication.
- [ ] After the shared helper lands, keep running manual browser tests (upload/save/delete/reorder) to guard against regressions.

### 2. Issues To Fix

- [ ] When Uppy uploads a file with the same name twice it still shows the “file too large” warning—show a proper duplicate-file warning instead.
- [x] Schedule attachments already expose a download button, but TODO attachments didn’t—feature parity restored.
