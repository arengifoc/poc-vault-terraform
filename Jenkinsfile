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

    environment {
        TF_VAR_region = 'us-east-1'
        // Definir variables necesarias
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                sh 'terraform init -input=false'
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
                sh 'terraform plan -input=false'
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
                sh 'terraform apply -auto-approve'
            }
        }
    }

    post {
        failure {
            mail to: 'devops@example.com',
                 subject: "Terraform Pipeline Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                 body: "Check Jenkins for details: ${env.BUILD_URL}"
        }
    }
}
