package tasks_test

import (
	"github.com/onsi/gomega/gexec"
	"gopkg.in/yaml.v2"
	"io/ioutil"
	"os/exec"
	"path/filepath"
	"testing"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

func TestTasks(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Tasks Suite")
}

var _ = Describe("With each task", func() {
	It("should have bash that passed `shellcheck`", func() {
		tasks, err := filepath.Glob("*.yml")
		Expect(err).ToNot(HaveOccurred())
		Expect(len(tasks)).To(BeNumerically(">", 0))

		type task struct {
			Run struct {
				Args []string
			}
		}

		for _, filename := range tasks {
			contents, err := ioutil.ReadFile(filename)
			Expect(err).ToNot(HaveOccurred())

			t := task{}
			err = yaml.Unmarshal(contents, &t)
			Expect(err).ToNot(HaveOccurred())

			tmpfile, err := ioutil.TempFile("", "")
			Expect(err).ToNot(HaveOccurred())
			defer tmpfile.Close()

			tmpfile.Write([]byte(t.Run.Args[1]))
			command := exec.Command("shellcheck", "-s", "bash", tmpfile.Name())
			session, err := gexec.Start(command, GinkgoWriter, GinkgoWriter)
			Expect(err).ToNot(HaveOccurred())
			Eventually(session, 5).Should(gexec.Exit(0))
		}
	})
})
