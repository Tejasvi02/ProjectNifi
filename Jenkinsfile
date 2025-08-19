pipeline {
  agent any
  stages {
    stage('Checkout') {
      steps { checkout scm }   // uses the SCM you set in the job UI (and its credentials)
    }
    stage('Terraform Apply') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          withEnv(['AWS_DEFAULT_REGION=us-east-2']) {
            dir('terraform') {
              sh '''
                terraform init -input=false
                terraform plan -out=tfplan -input=false
                terraform apply -auto-approve tfplan
              '''
            }
          }
        }
      }
    }
    stage('Generate Inventory') {
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'nifi-ec2-ssh', keyFileVariable: 'EC2_SSH_KEY')]) {
          sh 'bash scripts/make_inventory.sh'
          sh 'cat inventory.ini'
        }
      }
    }
    stage('Ansible: Java + NiFi + Props') {
      steps {
        sh '''
          ansible-playbook -i inventory.ini ansible/playbooks/install-java.yml \
            -e 'ansible_ssh_common_args=-o StrictHostKeyChecking=no'
          ansible-playbook -i inventory.ini ansible/playbooks/install-nifi.yml \
            -e 'ansible_ssh_common_args=-o StrictHostKeyChecking=no'
          ansible-playbook -i inventory.ini ansible/playbooks/update-nifi-properties.yml \
            -e 'ansible_ssh_common_args=-o StrictHostKeyChecking=no'
        '''
      }
    }
    stage('Smoke Test') {
      steps {
        sh '''
          IP=$(terraform -chdir=terraform output -raw instance_public_ip)
          curl -I --max-time 20 "http://${IP}:8443/nifi/" | head -n1
          echo "Open: http://${IP}:8443/nifi/"
        '''
      }
    }
  }
}
