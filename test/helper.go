package test

import (
	"fmt"
	"os"
	"os/exec"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

var (
	sleepBetweenRetries time.Duration = 1 * time.Minute
	retry               int           = 4
	aeroClusterSz       int           = 2
)

const (
	asClusterName  = "aerospikecluster"
	akoLabel       = "app=aerospike-kubernetes-operator"
	karpenterLabel = "app.kubernetes.io/name=karpenter"
	asClusterLabel = "aerospike.com/cr=aerospikecluster"

	asAuthSecret      = "auth-secret"
	asFkAndCertSecret = "aerospike-secret"
)

// CheckEnvVars sets multiple environment variables for the test.
func CheckEnvVars(t *testing.T, envVars []string) {
	t.Helper()

	for _, envVar := range envVars {
		val := os.Getenv(envVar)
		if val == "" {
			t.Fatalf("Environment variable `%s` is required and cannot be empty", envVar)
		} else {
			fmt.Printf("Using existing value for `%s` from environment\n", envVar)
		}
	}
}

// RunShellCommand executes a shell command and fails the test if it errors.
func RunShellCommand(t *testing.T, cmdName string, args ...string) {
	t.Helper()
	cmd := exec.Command(cmdName, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	err := cmd.Run()
	assert.NoError(t, err, fmt.Sprintf("Command %s %v failed", cmdName, args))
}

// UpdateKubeconfig runs the AWS CLI to set kubeconfig for the given cluster.
func UpdateKubeconfig(t *testing.T, region, clusterName string) {
	t.Helper()
	RunShellCommand(t, "aws", "eks", "--region", region, "update-kubeconfig", "--name", clusterName)
}

// RunInstallScript executes install.sh
func RunInstallScript(t *testing.T) {
	t.Helper()
	RunShellCommand(t, "../install.sh")
}

// RunCleanupScript executes cleanup.sh
func RunCleanupScript(t *testing.T) {
	t.Helper()
	RunShellCommand(t, "../cleanup.sh")
}
