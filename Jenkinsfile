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
                sh """
                    cd bld-01
                    terraform init
                """
               
                sh 'gcloud auth list'
                sh 'gcloud container clusters get-credentials wordspres-gke-euwe2 --region europe-west2 --project flash-keel-412418'
                sh 'kubectl get ns'
            }
        }
        stage('TF Validate'){
            steps{
                sh """
                    cd bld-01
                    terraform validate
                """
               
                sh 'gcloud auth list'
                sh 'gcloud container clusters get-credentials wordspres-gke-euwe2 --region europe-west2 --project flash-keel-412418'
                sh 'kubectl get ns'
            }
        }
        stage('TF Plan'){
            steps{
                sh """
                    cd bld-01
                    terraform plan
                """
               
                sh 'gcloud auth list'
                sh 'gcloud container clusters get-credentials wordspres-gke-euwe2 --region europe-west2 --project flash-keel-412418'
                sh 'kubectl get ns'
            }
        }
        stage('TF apply'){
            steps{
                /*
                script {
                    // Prompt the user for input
                    def userInput = input(
                        id: 'userInput',
                        message: 'Do you want to proceed?',
                        parameters: [
                            boolean(defaultValue: false, description: 'Proceed?', name: 'PROCEED')
                        ]
                    )

                    // Check the user's input
                    if (userInput.PROCEED) {
                        echo 'User chose to proceed.'
                        sh """
                        cd bld-01
                        terraform plan
                        """
                    } else {
                        error 'User chose not to proceed. Aborting the pipeline.'
                    }
                }
                */
                script {
                    // Prompt the user for input
                    def userInput = input(
                        id: 'userInput',
                        message: 'Do you want to proceed?',
                        parameters: [
                            [$class: 'BooleanParameterDefinition', defaultValue: false, description: 'Proceed?', name: 'PROCEED']
                        ]
                    )

                    // Check the user's input
                    if (userInput.PROCEED) {
                        echo 'User chose to proceed.'
                    sh """
                        cd bld-01
                        terraform plan
                        """
                    } else {
                        error 'User chose not to proceed. Aborting the pipeline.'
                    }
                }
        
           
            }
        }
 
    }
}