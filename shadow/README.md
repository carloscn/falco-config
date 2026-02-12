# falco idps
docker-compose up -d
docker exec -it falco-test-ubuntu bash
sudo /tmp/install_falco.sh
sudo falco &
cd /opt/falco-test && bash test_cases/run_all_idps_tests.sh
