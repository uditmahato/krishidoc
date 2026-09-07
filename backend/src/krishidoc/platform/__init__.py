"""Cross-cutting platform concerns: errors, logging, request identity.

Domain modules (identity, sync, advisory, ...) may import platform;
platform never imports domain modules. Enforced by import-linter once a
second module exists (D-26).
"""
