# Backup do SISPCARD

Scripts de backup do SISPCARD hospedado na Hostoo. O banco MySQL e os arquivos da aplicação são compactados localmente e enviados diretamente para o Amazon S3 com `rclone`.

## Backups

| Script | Conteúdo | Frequência |
| --- | --- | --- |
| `backup-critical.sh` | Banco `sispcard` e `~/public_html/upload` | 09h, 12h, 15h e 20h |
| `backup-application.sh` | Toda a pasta `~/public_html` | Domingo às 03h30 |

O backup completo também inclui arquivos gerados pelo sistema, como `~/public_html/lojista/relatorios/qrcode`.

Os scripts usam o fuso `America/Cuiaba`. Como o agendador do servidor opera em outro fuso, os horários do `cron` possuem uma hora de diferença:

```cron
# Backup crítico: 09h, 12h, 15h e 20h em Mato Grosso
0 10,13,16,21 * * * /home/efac84ck/scripts/backup-critical.sh >> /home/efac84ck/logs/backup-sispcard.log 2>&1

# Backup completo: domingo às 03h30 em Mato Grosso
30 4 * * 0 /home/efac84ck/scripts/backup-application.sh >> /home/efac84ck/logs/backup-application.log 2>&1
```

## Organização e retenção

Bucket: `assessoriatech-backups-sispcard`

```text
database/{intraday,daily,weekly,monthly,yearly}
files/{intraday,daily,weekly,monthly,yearly}
application/{weekly,monthly,yearly}
```

Todos os backups críticos vão para `intraday`. A execução das 20h também alimenta `daily` e, quando aplicável, `weekly`, `monthly` e `yearly`.

| Categoria | Retenção planejada |
| --- | --- |
| `intraday` | 7 dias |
| `daily` | 31 dias |
| `weekly` | 56 dias |
| `monthly` | 365 dias |
| `yearly` | Sem expiração |

A exclusão dos objetos antigos é responsabilidade do S3 Lifecycle; os scripts não removem backups do bucket.

## Configuração

O `rclone` fica em `~/bin/rclone` e usa `~/.config/rclone/rclone.conf`. Use [rclone.example.conf](rclone.example.conf) como modelo e proteja o arquivo real:

```bash
chmod 600 ~/.config/rclone/rclone.conf
chmod +x ~/scripts/backup-critical.sh ~/scripts/backup-application.sh
```

O dump do MySQL inclui rotinas, gatilhos e eventos. A opção `--no-tablespaces` evita a exigência do privilégio `PROCESS`, indisponível na hospedagem.

### Permissões IAM

Use um usuário IAM exclusivo para os backups, com estas permissões:

```text
s3:ListBucket
s3:GetObject
s3:PutObject
s3:AbortMultipartUpload
s3:ListMultipartUploadParts
```

Não conceda `s3:DeleteObject`. A remoção deve ser feita apenas pelas regras de Lifecycle do S3.

## Teste e verificação

Execute os scripts manualmente:

```bash
~/scripts/backup-critical.sh
~/scripts/backup-application.sh
```

Confira os arquivos enviados:

```bash
~/bin/rclone lsf s3:assessoriatech-backups-sispcard/database/intraday/
~/bin/rclone lsf s3:assessoriatech-backups-sispcard/files/intraday/
~/bin/rclone lsf s3:assessoriatech-backups-sispcard/application/weekly/
```

## Segurança e restauração

Nunca versione credenciais AWS ou MySQL, `rclone.conf`, `.env`, logs ou arquivos de backup.

O procedimento de restauração ainda precisa ser documentado. Até lá, valide periodicamente os backups por meio de uma restauração em ambiente isolado.
