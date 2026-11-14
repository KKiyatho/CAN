'use strict';

const { app } = require('@azure/functions');
const { DefaultAzureCredential } = require('@azure/identity');
const { createRecommendHandler } = require('../lib/recommend-core');

const credential = new DefaultAzureCredential();

const handler = createRecommendHandler({
  env: process.env,
  getToken: async () => (await credential.getToken('https://cognitiveservices.azure.com/.default')).token,
});

app.http('recommend', {
  methods: ['POST', 'OPTIONS'],
  authLevel: 'anonymous',
  route: 'recommend',
  handler,
});

app.http('health', {
  methods: ['GET'],
  authLevel: 'anonymous',
  route: 'health',
  handler: async () => ({ status: 200, jsonBody: { status: 'ok' } }),
});
