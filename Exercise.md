## Description

You’ve joined a fast-growing product team that needs a clean, reproducible path from development to
production for a tiny demo service. Leadership wants you to define the SDLC and ship a minimal deployment
of a sample app to Kubernetes, prioritizing clarity over bells and whistles.
The app to deploy is https://github.com/dockersamples/helloworld-demo-python.
Assume a managed Kubernetes cluster already exists in the cloud provider of your choice, and you have
credentials to target it; you are not creating the cluster.

## Technical requirements

- Deliver a top-level README.md covering: SDLC choices (branching, versioning, promotion policy),
how to run locally, how to provision/apply infrastructure, how CI/CD works (including triggers and
approvals), how to promote from dev → prod, and how to roll back.
- Use the sample app as the artifact, build a container image, and publish it to a registry of your
choice.
- Provision all application-layer infrastructure for two environments (dev and prod) with Terraform,
targeting the pre-existing managed Kubernetes cluster.
- Create only what the app needs: namespace, configuration, deployment, service, and an ingress or
other external exposure mechanism.
- Structure environments however you prefer (workspaces, separate state, or directories) and explain
the rationale in the README.
- Provide a CI/CD pipeline as code that builds, tags, pushes the image, applies Terraform to dev on
change, and promotes to prod with an approval gate.
- Include placeholder stages for tests and security/observability checks; they do not need to run.
- Make local development possible by documenting how to run the app in a container and how to
validate your Kubernetes manifests against a cluster.
- Ensure pipeline triggers and the promotion policy match your SDLC choices and are clearly
described.
- Provide simple acceptance criteria in the README describing what “done” looks like for dev and for
prod (expected URL or endpoint and sample output).
- Make sure that the pipeline and terraform code you write can be run.

