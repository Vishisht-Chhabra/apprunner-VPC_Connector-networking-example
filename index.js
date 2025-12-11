const express = require('express');
const app = express();
const port = 3000;
const axios = require('axios');
const { exec } = require('child_process');

app.get('/', (req, res) => {
  res.send('Hello World!');
});

app.get('/ip/:ipAddress', async (req, res) => {
  const ipAddress = req.params.ipAddress;

  try {
    const response = await axios.get(`http://ipinfo.io/${ipAddress}`);
    res.json(response.data);
  } catch (error) {
    console.error(error);
    res.status(500).send('Error fetching IP information');
  }
});

app.get('/ip-https/:ipAddress', async (req, res) => {
  const ipAddress = req.params.ipAddress;

  try {
    const response = await axios.get(`https://ipinfo.io/${ipAddress}`);
    res.json(response.data);
  } catch (error) {
    console.error(error);
    res.status(500).send('Error fetching IP information via HTTPS');
  }
});

app.get('/curl-ec2/:privateIp', (req, res) => {
  const privateIp = req.params.privateIp;

  exec(`curl http://${privateIp}`, (error, stdout, stderr) => {
    if (error) {
      console.error(`exec error: ${error}`);
      res.status(500).send('Error curling EC2 instance');
      return;
    }
    res.send(`Curl response from EC2 instance with private IP ${privateIp}:\n${stdout}`);
  });
});

app.listen(port, () => {
  console.log(`Example app listening at http://localhost:${port}`);
});
