pipeline{
    agent any
    stages{
        stage('Checkout'){
            steps{
                echo 'Checking out branch' + env.BRANCH_NAME
                checkout scm
                sh 'ls -lrt'
                
            }
        }
        stage('TF Initialize'){
            steps{
                sh 'terraform init'
                sh 'gcloud auth list'
                sh 'gcloud container clusters get-credentials wordspres-gke-euwe2 --region europe-west2 --project flash-keel-412418'
                sh 'kubectl get ns'
            }
        }
 
    }
}