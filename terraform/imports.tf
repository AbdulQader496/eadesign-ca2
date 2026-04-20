// Existing Azure resources are adopted through generated import blocks in CI.
// The workflow creates `generated-imports.tf` only for resources that already
// exist, so Terraform reuses them instead of attempting to recreate them.
