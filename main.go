package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/sirupsen/logrus"
)

const socketPath = "/flexmnt/nect.com~s3flex/socket"

// Options represents the options passed from kubelet to flexvolume for mounting the storage.
type Options struct {
	URL             string `json:"url"`
	Bucket          string `json:"bucket"`
	AccessKeyID     string `json:"kubernetes.io/secret/accessKeyID"`
	SecretAccessKey string `json:"kubernetes.io/secret/secretAccessKey"`
}

func main() {
	os.Remove(socketPath)

	server := http.Server{
		Handler: http.HandlerFunc(handleRequest),
	}

	unixListener, err := net.Listen("unix", socketPath)
	if err != nil {
		logrus.Panicf("couldn't listen on unix socket at `%s`, see: %v", socketPath, err)
	}

	server.Serve(unixListener)
}

func httpErr(w http.ResponseWriter, err string, code int) {
	logrus.Errorf("[%d] %s", code, err)
	http.Error(w, err, code)
}

func handleRequest(res http.ResponseWriter, req *http.Request) {
	mountPath := req.URL.Path
	logrus.Infof("Received request to %s", mountPath)

	buf, err := ioutil.ReadAll(req.Body)
	if err != nil {
		httpErr(res, fmt.Sprintf("couldnt read opts from body, see: %v", err), http.StatusBadRequest)
		return
	}

	defer req.Body.Close()

	var opts Options
	err = json.Unmarshal(buf, &opts)
	if err != nil {
		httpErr(res, fmt.Sprintf("couldnt decode json `%s`, see: %v", string(buf), err), http.StatusBadRequest)
		return
	}

	if opts.URL == "" {
		httpErr(res, "missing url in options", http.StatusBadRequest)
		return
	}

	if opts.Bucket == "" {
		httpErr(res, "missing bucket in options", http.StatusBadRequest)
		return
	}

	if opts.AccessKeyID == "" {
		httpErr(res, "missing kubernetes.io/secret/accessKeyID in options", http.StatusBadRequest)
		return
	}

	if opts.SecretAccessKey == "" {
		httpErr(res, "missing kubernetes.io/secret/secretAccessKey in options", http.StatusBadRequest)
		return
	}

	decodedAccessKeyID, err := base64.StdEncoding.DecodeString(opts.AccessKeyID)
	if err != nil {
		httpErr(res, fmt.Sprintf("couldnt decode access key id, see: %v", err), http.StatusBadRequest)
		return
	}

	opts.AccessKeyID = string(decodedAccessKeyID)

	decodedSecretAccessKey, err := base64.StdEncoding.DecodeString(opts.SecretAccessKey)
	if err != nil {
		httpErr(res, fmt.Sprintf("couldnt decode secret access key, see: %v", err), http.StatusBadRequest)
		return
	}

	opts.SecretAccessKey = string(decodedSecretAccessKey)
	expectedPrefix := "/var/lib/kubelet/pods/"

	if !strings.HasPrefix(mountPath, expectedPrefix) {
		httpErr(res, fmt.Sprintf("expected mount point to start with `%s` but it is `%s`", expectedPrefix, mountPath), http.StatusBadRequest)
		return
	}

	mountPath = strings.Replace(mountPath, expectedPrefix, "/hostPods/", 1)

	logrus.Infof("mounting bucket %s on s3 %s to %s", opts.Bucket, opts.URL, mountPath)
	err = mountS3FS(mountPath, &opts)
	if err != nil {
		httpErr(res, fmt.Sprintf("couldnt mount s3fs, see: %v", err), http.StatusBadRequest)
		return
	}
	logrus.Infof("mounted bucket %s on s3 %s to %s", opts.Bucket, opts.URL, mountPath)

	res.WriteHeader(200)
}

func mountS3FS(mountDir string, opts *Options) error {
	s3fsArgs := []string{
		opts.Bucket,
		mountDir,
		"-o", "url=" + opts.URL,
		"-o", "allow_other",
		"-o", "use_path_request_style",
		"-f",
	}

	proc := exec.Command("s3fs", s3fsArgs...)
	proc.Env = append(proc.Env, "AWSACCESSKEYID="+opts.AccessKeyID, "AWSSECRETACCESSKEY="+opts.SecretAccessKey)

	var stdout []byte
	var err error
	finished := false

	go (func() {
		stdout, err = proc.CombinedOutput()
		finished = true
		logrus.Infof("%s: %s %v", mountDir, stdout, err)
	})()

	// Fucking awful hack to make sure no connection failure happend...
	// We really should watch the output and find out if there's something where we know "yay, now its mounted successfully"
	for i := 0; i < 20; i++ {
		if finished || err != nil {
			return fmt.Errorf("%s %v", string(stdout), err)
		}

		time.Sleep(time.Second)
	}

	return nil
}
