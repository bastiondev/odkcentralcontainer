const { connect } = require("../lib/model/database");
const { createUser, promoteUser } = require('../lib/task/account');

// Bootstraps an administrator user with the given email and password.
// Closes the connection when done as it is intended to be used outside
// of the application.
const bootstrapAdmin = (connectionSettings, email, password) => {
  const db = connect(connectionSettings);
  db('users').count().then((results) => {
    if (results[0]['count'] === '0') {
      console.log("Bootstrapping first admin user, " + email);
      createUser(email, password).then(() => promoteUser(email));
    } else {
      console.log("Users already exist, not bootstrapping admin");
    }
  }).finally(() => db.destroy());
}

module.exports = { bootstrapAdmin };
