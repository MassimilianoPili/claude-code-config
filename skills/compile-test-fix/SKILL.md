---
name: compile-test-fix
description: Compile-Test-Fix Loop. Detects project language (pom.xml, package.json, go.mod, Cargo.toml), compiles, runs tests, and if tests fail, analyzes the error and attempts a fix. Max 3 retries. Use after completing a feature or fixing a bug to verify the code compiles and tests pass.
allowed-tools: Read, Bash, Edit, Grep, Glob
category: automation
tags: [compile, test, fix, loop, ci, maven, npm, go, cargo]
version: 1.0.0
---

# Compile-Test-Fix Loop

Automated loop: detect language → compile → test → if fail, analyze and fix → retry (max 3).

## When to use

After writing or modifying code, invoke this skill to verify the project builds and tests pass. Do NOT use on projects without tests or build files.

## Detection rules

Detect the project by looking for build files starting from the current working directory, walking up:

| File | Language | Compile | Test |
|------|----------|---------|------|
| `pom.xml` | Java/Maven | `mvn compile -q` | `mvn test -q` |
| `build.gradle` | Java/Gradle | `./gradlew compileJava` | `./gradlew test` |
| `package.json` | Node.js | `npm run build --if-present` | `npm test` |
| `go.mod` | Go | `go build ./...` | `go test ./...` |
| `Cargo.toml` | Rust | `cargo build` | `cargo test` |
| `pyproject.toml` | Python | — | `pytest` |

## Algorithm

```
for attempt in 1..3:
    1. Detect project type (walk up from cwd to find build file)
    2. Compile (if applicable)
       - If compile fails: analyze error, fix, continue to next attempt
    3. Run tests
       - If tests pass: done, report success
       - If tests fail: analyze failure output, identify failing test and root cause
    4. Fix the issue (edit source, not test)
    5. If attempt == 3 and still failing: report what was tried and what failed
```

## Important constraints

- **Max 3 attempts**. If still failing after 3, stop and report.
- **Fix source code, not tests** (unless the test itself has a bug).
- **Never skip tests** (`-DskipTests`, `--no-verify`, etc.).
- **Read the error output carefully** before attempting a fix.
- **For Maven**: use `/opt/maven/bin/mvn` (not `mvn`).
- **For large projects**: run only the failing test module, not the full suite.
  - Maven: `mvn test -pl <module> -am -Dtest=FailingTest`

## Example invocation

User says: "compile and test the orchestrator module"

```bash
# Step 1: Detect
# Found pom.xml at /data/massimiliano/agent-framework/pom.xml → Maven

# Step 2: Compile
/opt/maven/bin/mvn compile -pl control-plane/orchestrator -am -q

# Step 3: Test
/opt/maven/bin/mvn test -pl control-plane/orchestrator -q

# If test fails → read output → fix → retry
```

## Output

Report at the end:
- Project type detected
- Compile result (pass/fail)
- Test result (pass/fail, which tests)
- Fixes applied (if any)
- Attempts used (1-3)
