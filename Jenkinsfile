pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: terraform
    image: hashicorp/terraform:1.6.6
    command:
    - cat
    tty: true
"""
        }
    }

    options {
        ansiColor('xterm')
    }

    environment {
        VAULT_ADDR = 'https://vault.angelrengifo.com'
        ROLE_ID = credentials('vault-approle-cicd-role-id')
        SECRET_ID = credentials('vault-approle-cicd-secret-id')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Autenticarse con Vault') {
            steps {
                script {
                    def GetVaultToken = sh(
                        script: '''
                        curl -sLo jq https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64
                        chmod +x jq
                        curl -sX POST -d '{"role_id":"'$ROLE_ID'","secret_id":"'$SECRET_ID'"}' \
                            $VAULT_ADDR/v1/auth/approle/login | ./jq -r '.auth.client_token'
                        ''',
                        returnStdout: true
                    ).trim()

                    // Establecer VAULT_TOKEN en el entorno antes de usarlo
                    env.VAULT_TOKEN = GetVaultToken

                    def gcpCreds = sh(
                        script: '''
                        curl -sH "X-Vault-Token: $VAULT_TOKEN" \
                          "$VAULT_ADDR/v1/gcp/roleset/terraform-admin/key?ttl=10m" \
                          | ./jq -r '.data.private_key_data' | base64 -d
                        ''',
                        returnStdout: true
                    ).trim()

                    // Mostrar el contenido de gcpCreds en la consola
                    echo "Contenido de gcpCreds:\n${gcpCreds}"
                    
                    // Guardar el archivo JSON localmente para usar con Terraform
                    writeFile file: 'gcp-creds.json', text: gcpCreds
                
                    // Seteamos variable que usará Terraform
                    env.GOOGLE_APPLICATION_CREDENTIALS = "${env.WORKSPACE}/gcp-creds.json"                    
                }
            }
        }

        stage('Depurar Credenciales GCP') {
            steps {
                script {
                    // Leer y mostrar el contenido del archivo gcp-creds.json
                    def gcpCredsContent = readFile 'gcp-creds.json'
                    echo "Contenido de gcp-creds.json:\n${gcpCredsContent}"
                }
            }
        }

        stage('Terraform Init') {
            steps {
                container('terraform') {
                    sh 'terraform init -input=false'
                }
            }
        }

        stage('Terraform Plan') {
            when {
                anyOf {
                    branch pattern: "PR-.*", comparator: "REGEXP"
                    changeRequest()
                }
            }
            steps {
                container('terraform') {
                    sh 'terraform plan -input=false'
                }
            }
        }

        stage('Terraform Apply') {
            when {
                allOf {
                    branch 'main'  // o el branch principal de producción
                    not { changeRequest() }
                }
            }
            steps {
                container('terraform') {
                    sh '''
                    echo Token es $VAULT_TOKEN
                    '''
                    sh 'terraform apply -auto-approve'
                }
            }
        }
    }

    post {
        failure {
            mail to: 'arengifoc@gmail.com',
                 subject: "Terraform Pipeline Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                 body: "Check Jenkins for details: ${env.BUILD_URL}"
        }
    }
}
