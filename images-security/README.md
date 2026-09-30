# Demo: gestão de vulnerabilidades e superfície de ataque

Esta demo une OpenShift Dev Spaces, Red Hat Dependency Analytics (RHDA), OpenShift Pipelines, Red Hat Advanced Cluster Security (RHACS/ACS), UBI e Red Hat Hardened Images (RHHI). Os arquivos da demo ficam nesta pasta.

## Estado deste laboratório

- OpenShift: `api.cluster-fhchw.dyn.redhatworkshops.io`, namespace `images-security`.
- ACS 4.11.4: Central e Secured Cluster instalados; nome do cluster no ACS: `my-cluster`.
- Pipelines 1.24: pipeline `images-security` criado no namespace da demo.
- Dev Spaces 3.30.2: `https://devspaces.apps.cluster-fhchw.dyn.redhatworkshops.io`.
- O devfile usa a imagem `admin-devspaces/images-security-devtools`, construída a partir de UBI com Maven, Git, gzip e OpenShift CLI. Recrie-a com `bash images-security/scripts/environment/build-devspaces-tools.sh` antes de abrir um workspace novo neste cluster.
- RHDA: extensão `redhat.fabric8-analytics`, disponível no Open VSX e instalada neste workspace. O Dev Spaces foi apontado para `https://open-vsx.org`; se a instalação automática não ocorrer em outro workspace, instale a extensão pela aba Extensions.

## Como funciona

```text
Dev Spaces + RHDA (pom.xml)
       │
       ▼
sync-source.sh → ConfigMap com snapshot do app e Containerfiles
       │
       ▼
OpenShift Pipeline: fetch → Buildah → roxctl image scan → roxctl image check
                                             │                    │
                                      inventário/CVEs       políticas FAIL_BUILD
                                                                  │
                                                                  └→ RHHI aprovada: deploy → rollout → HTTP
```

O pipeline produz quatro imagens da **mesma aplicação**:

| Tag | Dependências | Runtime | Demonstração |
| --- | --- | --- | --- |
| `community-unsafe` | Perfil Maven `unsafe` com Log4j 2.14.1 e Commons Collections 3.2.1 | `eclipse-temurin:17-jre` | Má prática no código e runtime amplo; deve disparar a política Log4Shell. |
| `community-none` | Perfil padrão | `eclipse-temurin:17-jre` | Isola a influência do runtime community após corrigir o código. |
| `ubi-none` | Perfil padrão | `ubi9/openjdk-17-runtime` | Runtime Red Hat suportado, mais enxuto que o builder. |
| `rhhi-none` | Perfil padrão | `hi/openjdk:21-runtime` | Runtime Hardened sem shell, com inventário reduzido de pacotes de sistema. |

O builder é o mesmo `ubi9/openjdk-17` em todos os casos. O build multi-stage só copia o artefato Quarkus para o runtime. A dependência vulnerável da primeira imagem não é corrigida por trocar a imagem base: isso separa claramente a responsabilidade do desenvolvedor da escolha de runtime.

## Preparação e execução

O cluster deste laboratório já recebeu os manifests. Para recriar em outro cluster:

```bash
oc apply -f images-security/openshift/pipeline.yaml
oc apply -f images-security/openshift/acs-policies.yaml
oc apply -f images-security/openshift/devspaces.yaml
# Depois que o operador Dev Spaces estiver Succeeded:
oc apply -f images-security/openshift/checluster.yaml
bash images-security/scripts/environment/configure-acs-token.sh
bash images-security/scripts/environment/build-devspaces-tools.sh
# Depois de criar o DevWorkspace, vincule sua ServiceAccount à Role de demonstração:
oc apply -f images-security/openshift/devspaces-demo-access.yaml
```

O `RoleBinding` em `devspaces-demo-access.yaml` aponta para a ServiceAccount do workspace validado neste laboratório. Ao criar outro workspace, substitua o nome da ServiceAccount no manifesto pelo valor `<status.devworkspaceId>-sa` do novo DevWorkspace antes de aplicar. A Role permite publicar o ConfigMap, criar PipelineRuns e ler seus resultados apenas no namespace `images-security`.

O script do token usa a senha local de administração do ACS e cria um token com papel **Continuous Integration**, armazenado apenas no Secret `images-security/rox-api-token`. Não grava o token no Git. Em ambientes sem o Secret `central-htpasswd`, crie um token Continuous Integration no portal ACS e salve-o com `oc -n images-security create secret generic rox-api-token --from-literal=token='<TOKEN>'`.

Depois de qualquer edição local ou no terminal do Dev Spaces, atualize o snapshot:

```bash
bash images-security/scripts/ci-cd/sync-source.sh
```

Execute um script por vez, aguardando o PipelineRun terminar antes de iniciar o próximo. Isso evita quatro builds simultâneos no nó deste laboratório:

```bash
bash images-security/scripts/ci-cd/run-community-unsafe.sh
bash images-security/scripts/ci-cd/run-community-none.sh
bash images-security/scripts/ci-cd/run-ubi-none.sh
bash images-security/scripts/ci-cd/run-rhhi-none.sh
```

Cada comando cria **somente um** PipelineRun; execute apenas a linha do cenário que deseja demonstrar. Acompanhe com `oc -n images-security get pipelineruns -w`. Para ver scan e gate: `oc -n images-security logs <taskrun-pod> -c step-scan` e `oc -n images-security logs <taskrun-pod> -c step-policy-gate`, ou abra o PipelineRun na console OpenShift.

Somente a variante `rhhi-none` que passa pelo Image Check executa `deploy-rhhi`. O CD aplica `rhhi-deployment.yaml` com o **digest do Buildah**, aguarda o Deployment ficar disponível e consulta `/vulnerabilities` pelo Service. A Route HTTPS é `security-demo-rhhi`; obtenha o endereço no terminal do Dev Spaces:

```bash
oc -n images-security get route security-demo-rhhi -o jsonpath='https://{.spec.host}/vulnerabilities{"\n"}'
oc -n images-security get deployment security-demo-rhhi
```

Para demonstrar a ausência de shell na imagem final, execute no Dev Spaces:

```bash
oc -n images-security exec deployment/security-demo-rhhi -- /bin/bash -c true
oc -n images-security exec deployment/security-demo-rhhi -- /bin/sh -c true
```

Ambos os comandos devem falhar com `executable file ... not found`. O build usa shell apenas no estágio UBI; o estágio final `hi/openjdk:21-runtime` copia somente a aplicação.

## Roteiro de apresentação (15–20 minutos)

1. **IDE e análise de dependências.** Abra `https://devspaces.apps.cluster-fhchw.dyn.redhatworkshops.io#https://github.com/le0nard01/ai-security-workflow.git?devfilePath=images-security/devfile.yaml` quando esta pasta estiver publicada no Git. No IDE, abra `images-security/rhda-unsafe/pom.xml` e clique em **Open Red Hat Dependency Analytics Report**: Log4j 2.14.1 e Commons Collections 3.2.1 aparecem com vulnerabilidades e remediações. Compare com `images-security/app/pom.xml`, cujo perfil padrão não inclui essas bibliotecas. Execute os comandos `show-dependencies`, `build-unsafe` e `build-safe` do devfile. O relatório do RHDA analisa dependências de aplicação; não substitui o scan de imagem do ACS.
2. **Pipeline e Image Scan.** Execute os scripts de preparação acima. Mostre `fetch`, `build` e `image-scan` nos quatro PipelineRuns. O `roxctl image scan` mostra pacotes e CVEs encontrados pelo ACS; use os números reais do momento, pois feeds e tags mudam.
3. **Image Check com bloqueio.** Abra a Task `image-check`. As políticas em `acs-policies.yaml` têm ciclo **BUILD** e ação **FAIL_BUILD**: `Log4Shell` procura CVE-2021-44228; `Gerenciador no runtime` procura `rpm` ou `dpkg`. Compare os PipelineRuns aprovados e reprovados. O resultado exato depende do inventário publicado pelo Scanner V4 e dos feeds atuais. Políticas padrão do ACS também podem bloquear um build se aparecerem novos CVEs corrigíveis.
4. **CD da RHHI.** Abra a Task `deploy-rhhi` no PipelineRun aprovado. Mostre o digest fixado no Deployment, o rollout concluído, o smoke test HTTP e a Route HTTPS. Os três PipelineRuns bloqueados não fazem deploy.
5. **Redução da superfície de ataque.** Compare `community-none`, `ubi-none` e `rhhi-none`: aplicação e dependências iguais, somente runtime diferente. No ACS, abra o inventário/SBOM de cada tag e anote **número de componentes do SO**, **CVEs do SO**, **tamanho** e presença de gerenciador de pacotes. Execute os testes de `bash` e `sh` acima no pod RHHI. A RHHI foi desenhada para remover utilitários de runtime desnecessários; uma quantidade menor de pacotes reduz pontos potencialmente exploráveis, mas não garante zero CVEs. Compare também os CVEs da aplicação separadamente dos do sistema operacional.
6. **Remediação.** Mostre que a versão sem o perfil `unsafe` elimina a dependência Log4j antiga. Refaça o `sync-source.sh` e o pipeline após qualquer correção no `pom.xml`; o gate aplica as políticas novamente.

### Medição neste cluster (30/09/2026)

| Variante | Componentes no Image Scan | Vulnerabilidades no Image Scan | Tamanho da imagem | Gerenciador encontrado | Image Check |
| --- | ---: | ---: | ---: | --- | --- |
| community-unsafe | 34 | 81, incluindo 3 críticas | 131.299.288 bytes | `dpkg` | bloqueado: Log4Shell, gerenciador e política padrão |
| community-none | 31 | 71 | 128.817.682 bytes | `dpkg` | bloqueado: gerenciador e política padrão |
| ubi-none | 52 | 225 | 147.961.401 bytes | `rpm` | bloqueado: gerenciador e política padrão |
| rhhi-none | 6 | 4 | 107.721.950 bytes | nenhum dos dois | aprovado, 0 violações |

Os totais são os campos `TOTAL-COMPONENTS` e `TOTAL-VULNERABILITIES` emitidos pelo `roxctl image scan`; não representam todos os pacotes do SBOM nem separam automaticamente vulnerabilidades do SO e da aplicação. Para a comparação controlada com perfil Maven padrão, a RHHI apresentou **88% menos componentes reportados que UBI** (6 vs. 52) e **81% menos que a community** (6 vs. 31). As contagens de CVEs também foram menores nesta execução, mas mudam com as tags, feeds e critérios de classificação de cada distribuição. O tamanho da imagem RHHI também foi menor nesta execução; tamanho, inventário e risco são medidas diferentes.

Use os digests dos builds executados e registre novamente a data ao repetir a demo. Uma biblioteca Java vulnerável inserida na aplicação continua no scan mesmo com uma base Hardened.

## Arquivos

- `app/`: aplicação Quarkus e perfil Maven vulnerável.
- `rhda-unsafe/`: manifesto Maven com dependências vulneráveis explícitas para o relatório RHDA.
- `containers/`: três Containerfiles com builder comum e runtimes distintos.
- `devfile.yaml` e `.vscode/extensions.json`: ambiente Dev Spaces e RHDA.
- `openshift/`: Pipeline, políticas ACS, Deployment/Service/Route RHHI e instalação do Dev Spaces.
- `scripts/environment/`: preparação do ACS e da imagem de ferramentas do Dev Spaces.
- `scripts/ci-cd/`: sincronização do código e um script para cada PipelineRun.

## Referências oficiais

- [RHACS 4.11: `roxctl image scan` e `image check`](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_security_for_kubernetes/4.11/html/roxctl_cli/roxctl-cli-command-reference)
- [RHACS 4.11: políticas como código](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_security_for_kubernetes/4.11/html/operating/using-policies-to-provide-security)
- [RHHI: modelo builder/runtime e superfície mínima](https://docs.redhat.com/en/documentation/red_hat_hardened_images/1-latest/html-single/build_and_deploy_secure_minimal_containers_with_red_hat_hardened_images/index)
- [Dev Spaces: `devfilePath` em URL de workspace](https://docs.redhat.com/en/documentation/red_hat_openshift_dev_spaces/3.29/html/user_guide/optional-parameters-for-urls_user_guide)
