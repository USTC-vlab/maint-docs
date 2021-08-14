package main

import (
	"archive/tar"
	"io"
	"log"
	"os"
)

func main() {
	tr := tar.NewReader(os.Stdin)
	tw := tar.NewWriter(os.Stdout)

	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		} else if err != nil {
			log.Fatal(err)
		}

		hdr.Uid -= 100000
		hdr.Gid -= 100000
		if err := tw.WriteHeader(hdr); err != nil {
			log.Fatal(err)
		}

		if hdr.Typeflag == tar.TypeReg {
			if _, err := io.Copy(tw, tr); err != nil {
				log.Fatal(err)
			}
		}
	}

	if err := tw.Close(); err != nil {
		log.Fatal(err)
	}
}
