# Issues

## Terraform tries to replace all variables within the templated script, so it fails.

As a workaround, an extra dollar symbol ($) has been added to the variables that doesn't need to be replaced by terraform templating.

See https://discuss.hashicorp.com/t/invalid-value-for-vars-parameter-vars-map-does-not-contain-key-issue/12074/4 & https://github.com/hashicorp/terraform/issues/23384 

## The loopback interface for API LB cannot be up until K3s is fully installed in the extra control plane nodes