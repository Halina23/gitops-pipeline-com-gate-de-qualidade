package main

# Validação de política complementar ao gate de IA: aqui checamos práticas
# básicas de manifesto Kubernetes que o gate de IA (revisão de código/diff)
# não teria como pegar, já que ele não tem visão do estado final do YAML.

deny[msg] {
	input.kind == "Deployment"
	container := input.spec.template.spec.containers[_]
	not container.resources.limits
	msg := sprintf("Deployment '%s' container '%s' nao define resources.limits", [input.metadata.name, container.name])
}

deny[msg] {
	input.kind == "Deployment"
	container := input.spec.template.spec.containers[_]
	not container.resources.requests
	msg := sprintf("Deployment '%s' container '%s' nao define resources.requests", [input.metadata.name, container.name])
}

deny[msg] {
	input.kind == "Deployment"
	container := input.spec.template.spec.containers[_]
	not container.readinessProbe
	msg := sprintf("Deployment '%s' container '%s' nao define readinessProbe", [input.metadata.name, container.name])
}

deny[msg] {
	input.kind == "Deployment"
	container := input.spec.template.spec.containers[_]
	not container.livenessProbe
	msg := sprintf("Deployment '%s' container '%s' nao define livenessProbe", [input.metadata.name, container.name])
}

deny[msg] {
	input.kind == "Deployment"
	container := input.spec.template.spec.containers[_]
	endswith(container.image, ":latest")
	msg := sprintf("Deployment '%s' container '%s' usa a tag ':latest' (fixe uma versao)", [input.metadata.name, container.name])
}

deny[msg] {
	input.kind == "Deployment"
	container := input.spec.template.spec.containers[_]
	not contains(container.image, ":")
	msg := sprintf("Deployment '%s' container '%s' nao especifica uma tag de imagem", [input.metadata.name, container.name])
}

deny[msg] {
	namespaced_kinds := {"Deployment", "Service", "ServiceAccount"}
	namespaced_kinds[input.kind]
	not input.metadata.namespace
	msg := sprintf("%s '%s' nao define metadata.namespace", [input.kind, input.metadata.name])
}
