const { createAIProviderFromEnv } = require("./lib/providers/provider_factory");
const { createRepositoryFromEnv } = require("./lib/repositories/firestore_repositories");
const {
  processDreamEntryDatabaseEvent,
} = require("./lib/triggers/dream_entry");

exports.main = async (event = {}) => {
  return processDreamEntryDatabaseEvent({
    event,
    repo: createRepositoryFromEnv(),
    provider: createAIProviderFromEnv(),
  });
};
