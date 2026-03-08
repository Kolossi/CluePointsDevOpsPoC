# Prod environment — non-secret configuration.
# 'image' and 'ingress_base_domain' are supplied at runtime:
#   image               — passed by CI as -var "image=..."
#   ingress_base_domain — set via TF_VAR_ingress_base_domain CI variable
