# GitHub History Cleanup (Secrets)

This procedure removes sensitive files from Git history and force-pushes the rewritten history.

## 1) Rotate secrets first

Rotate anything previously committed:
- JWT secret
- DB passwords
- Any OAuth client secret
- Any signing credentials if exposed

## 2) Create a mirror clone

```bash
git clone --mirror git@github.com:martin-dnl/dart-district-flutter.git
cd dart-district-flutter.git
```

## 3) Rewrite history with git-filter-repo

Install `git-filter-repo` if needed, then run:

```bash
git filter-repo --force \
  --path backend/.env \
  --path backend/.env.prod \
  --path android/key.properties \
  --path config/flutter.env.json \
  --path config/flutter.env.prod.json \
  --invert-paths
```

## 4) Validate cleanup

```bash
git log -- backend/.env
git log -- android/key.properties
```

Both commands should return no commits.

## 5) Force-push rewritten history

```bash
git push origin --force --all
git push origin --force --tags
```

## 6) Team coordination

All collaborators must re-clone, or hard reset to the new history before pushing again.

## 7) Enable protection locally

From repository root (PowerShell):

```powershell
./scripts/enable-git-hooks.ps1
```

This repo uses `.githooks/pre-commit` to block common secret leaks.
