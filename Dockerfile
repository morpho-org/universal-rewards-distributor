FROM ubuntu:latest
WORKDIR /usr/rewards-checker

RUN apt update
RUN apt install python3-pip git curl -y
RUN pip install web3 eth-tester py-evm

RUN curl -L https://foundry.paradigm.xyz | bash
ENV PATH="${PATH}:/root/.foundry/bin/"
RUN foundryup

COPY . .
RUN python3 certora/checker/create_certificate.py proofs.json
RUN FOUNDRY_PROFILE=checker forge test
