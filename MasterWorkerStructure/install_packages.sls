install_kubernetes_app:
  pkg.installed:
    - name: k3s

run_kubernetes_app:
  cmd.run:
    - name: kubectl apply -f /path/to/your/kubernetes/app.yaml
    - require:
      - pkg: install_kubernetes_app