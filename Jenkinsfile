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
          withEnv(['AWS_DEFAULT_REGION=us-east-1']) {
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
    withCredentials([sshUserPrivateKey(credentialsId: 'nifi-ec2-ssh', keyFileVariable: 'EC2_SSH_KEY')]) {
      sh '''
        export ANSIBLE_HOST_KEY_CHECKING=False
        export ANSIBLE_PRIVATE_KEY_FILE="$EC2_SSH_KEY"

        ansible --version
        ansible-playbook -i inventory.ini ansible/playbooks/install-java.yml
        ansible-playbook -i inventory.ini ansible/playbooks/install-nifi.yml
        ansible-playbook -i inventory.ini ansible/playbooks/update-nifi-properties.yml
      '''
    }
  }
}
    stage('NiFi Debug') {
        steps {
            withCredentials([sshUserPrivateKey(credentialsId: 'nifi-ec2-ssh', keyFileVariable: 'EC2_SSH_KEY')]) {
            sh '''
                IP=$(terraform -chdir=terraform output -raw instance_public_ip)
                ssh -o StrictHostKeyChecking=no -i "$EC2_SSH_KEY" ubuntu@$IP '
                echo "--- systemctl status nifi ---"
                sudo systemctl status nifi --no-pager -l || true
                echo "--- listening ports ---"
                sudo ss -lntp | egrep ":8443|:8080" || true
                echo "--- nifi.properties (web settings) ---"
                grep -E "nifi.web.(http|https).(host|port)" /home/ubuntu/nifi_infra_creation/nifi-1.26.0/conf/nifi.properties || true
                echo "--- last 80 lines of nifi-app.log ---"
                tail -n 80 /home/ubuntu/nifi_infra_creation/nifi-1.26.0/logs/nifi-app.log || true
                echo "--- last 80 lines of bootstrap.log ---"
                tail -n 80 /home/ubuntu/nifi_infra_creation/nifi-1.26.0/logs/bootstrap.log || true
                '
            '''
            }
        }
    }
    stage('Wait for NiFi') {
        steps {
            sh '''
            IP=$(terraform -chdir=terraform output -raw instance_public_ip)
            echo "Waiting for NiFi on http://${IP}:8443/nifi/ ..."
            for i in $(seq 1 60); do
                if curl -s -o /dev/null --max-time 2 "http://${IP}:8443/nifi/"; then
                echo "NiFi is up!"
                exit 0
                fi
                sleep 5
            done
            echo "NiFi did not respond in time" >&2
            exit 1
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
