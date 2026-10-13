# Politica de seguridad

## Reportar una vulnerabilidad
No abrir un issue publico. Usar **Security -> Report a vulnerability** (GitHub private
vulnerability reporting) o escribir al equipo de seguridad. Respuesta inicial: 3 dias habiles.

## Criterios de bloqueo del pipeline
| Control | Bloquea el merge si... |
|---|---|
| Secrets (gitleaks) | aparece cualquier secreto |
| SAST (bandit/semgrep) | hay hallazgos MEDIUM o superiores |
| SCA (pip-audit) | alguna dependencia tiene CVE con fix disponible |
| Imagen (trivy) | hay CVEs HIGH/CRITICAL con fix disponible |

Las excepciones se documentan (archivo `.trivyignore`, `# nosec <ID>` o `# nosemgrep`) con
**motivo, responsable y fecha de vencimiento**.
