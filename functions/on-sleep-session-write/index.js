const { createAIProviderFromEnv } = require("./lib/providers/provider_factory");
const { createRepositoryFromEnv } = require("./lib/repositories/firestore_repositories");
const {
  processSleepSessionDatabaseEvent,
} = require("./lib/triggers/sleep_session");

exports.main = async (event = {}) => {
  return processSleepSessionDatabaseEvent({
    event,
    repo: createRepositoryFromEnv(),
    provider: createAIProviderFromEnv(),
  });
};
