package test

import (
	"fmt"
	"os"
	"testing"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestAerospikeBlueprint(t *testing.T) {
	tfOptions := &terraform.Options{
		TerraformDir: "../",
	}

	// awsRegion should be same as region in the .tfvars file
	envVars := []string{
		"TF_VAR_aerospike_admin_password",
		"TF_VAR_aerospike_secret_files_path",
		"AWS_DEFAULT_REGION",
	}
	CheckEnvVars(t, envVars)

	defer RunCleanupScript(t)
	RunInstallScript(t)

	// Get region and clusterName from the terraform output
	region := terraform.Output(t, tfOptions, "region")
	clusterName := terraform.Output(t, tfOptions, "eks_cluster_name")

	// Use default kubeconfig path
	kubeConfigPath := fmt.Sprintf("%s/.kube/config", os.Getenv("HOME"))
	UpdateKubeconfig(t, region, clusterName)

	// Set up common Kubectl options
	kubeSystemOpts := k8s.NewKubectlOptions("", kubeConfigPath, "kube-system")
	karpenterOpts := k8s.NewKubectlOptions("", kubeConfigPath, "karpenter")
	akoOpts := k8s.NewKubectlOptions("", kubeConfigPath, "aerospike-operator")
	aerospikeOpts := k8s.NewKubectlOptions("", kubeConfigPath, "aerospike")

	// Run all the tests
	t.Run("TestClusterReachability", func(t *testing.T) {
		_, err := k8s.RunKubectlAndGetOutputE(t, kubeSystemOpts, "get", "nodes")
		assert.NoError(t, err, "Cluster should be reachable via kubectl")
	})

	t.Run("TestKarpenterControllerPod", func(t *testing.T) {
		filters := metav1.ListOptions{LabelSelector: karpenterLabel}
		err := k8s.WaitUntilNumPodsCreatedE(t, karpenterOpts, filters, 2, retry, sleepBetweenRetries)
		assert.NoError(t, err)

		pods := k8s.ListPods(t, karpenterOpts, filters)
		for _, pod := range pods {
			err := k8s.WaitUntilPodAvailableE(t, karpenterOpts, pod.Name, retry, sleepBetweenRetries)
			assert.NoError(t, err)
		}
	})

	t.Run("TestKarpenterCRDs", func(t *testing.T) {
		output, err := k8s.RunKubectlAndGetOutputE(t, karpenterOpts, "get", "nodepool")
		assert.NoError(t, err, "Karpenter nodepool should have been created")
		// Karpenter creates aerospike and default nodepool
		assert.Contains(t, output, "aerospike")

		output, err = k8s.RunKubectlAndGetOutputE(t, karpenterOpts, "get", "ec2nodeclass")
		assert.NoError(t, err, "Karpenter ec2nodeclass should have been created")
		// Karpenter creates default ec2nodeclass
		assert.Contains(t, output, "default")
	})

	// If AKO and aerospike pods are running then it means karpenter is working fine
	t.Run("TestAKOOperatorPod", func(t *testing.T) {
		filters := metav1.ListOptions{LabelSelector: akoLabel}
		err := k8s.WaitUntilNumPodsCreatedE(t, akoOpts, filters, 2, retry, sleepBetweenRetries)
		assert.NoError(t, err)

		pods := k8s.ListPods(t, akoOpts, filters)
		for _, pod := range pods {
			err := k8s.WaitUntilPodAvailableE(t, akoOpts, pod.Name, retry, sleepBetweenRetries)
			assert.NoError(t, err)
		}
	})

	t.Run("TestAerospikeSecrets", func(t *testing.T) {
		secret := k8s.GetSecret(t, aerospikeOpts, asAuthSecret)
		assert.NotNil(t, secret)

		secret = k8s.GetSecret(t, aerospikeOpts, asFkAndCertSecret)
		assert.NotNil(t, secret)
	})

	t.Run("TestAerospikePodsRunning", func(t *testing.T) {
		filters := metav1.ListOptions{LabelSelector: asClusterLabel}
		err := k8s.WaitUntilNumPodsCreatedE(t, aerospikeOpts, filters, aeroClusterSz, retry, sleepBetweenRetries)
		assert.NoError(t, err)

		pods := k8s.ListPods(t, aerospikeOpts, filters)
		for _, pod := range pods {
			err := k8s.WaitUntilPodAvailableE(t, aerospikeOpts, pod.Name, retry, sleepBetweenRetries)
			assert.NoError(t, err)
		}
	})

	t.Run("TestAerospikeScaleupAndDown", func(t *testing.T) {
		newSize := aeroClusterSz + 1

		// Scaleup to new size
		ScaleAerospikeCluster(t, aerospikeOpts, asClusterName, newSize)

		// Scaledown to old size
		ScaleAerospikeCluster(t, aerospikeOpts, asClusterName, aeroClusterSz)
	})
}

func ScaleAerospikeCluster(t *testing.T, options *k8s.KubectlOptions, clusterName string, newSize int) {
	// Construct the patch payload
	// CMD: kubectl patch aerospikecluster aerospikecluster -p '{"spec": {"size": 3}}'
	patch := fmt.Sprintf(`{"spec": {"size": %d}}`, newSize)

	// Apply the patch using kubectl
	_, err := k8s.RunKubectlAndGetOutputE(t, options, "patch", asClusterName, clusterName, "--type", "merge", "-p", patch)
	assert.NoError(t, err, "Failed to scale Aerospike cluster")

	// Wait and verify cluster scaleup
	filters := metav1.ListOptions{LabelSelector: asClusterLabel}
	err = k8s.WaitUntilNumPodsCreatedE(t, options, filters, newSize, retry*2, sleepBetweenRetries)
	assert.NoError(t, err)

	pods := k8s.ListPods(t, options, filters)
	for _, pod := range pods {
		err := k8s.WaitUntilPodAvailableE(t, options, pod.Name, retry, sleepBetweenRetries)
		assert.NoError(t, err)
	}
}
