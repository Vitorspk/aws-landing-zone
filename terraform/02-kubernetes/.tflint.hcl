plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Ignore specific rules that may cause issues
rule "terraform_unused_declarations" {
  enabled = false  # Disable to avoid false positives
}

rule "terraform_required_providers" {
  enabled = false  # We have the providers configured
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = false
}

rule "terraform_documented_variables" {
  enabled = false
}

rule "terraform_naming_convention" {
  enabled = false
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = false
}

rule "terraform_standard_module_structure" {
  enabled = false
}
