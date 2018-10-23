import elasticsearchClient from './elasticsearchConnection.js';

/**
 * Elasticsearch search API
 */

export default {
  /**
   * 사용자의 질의 조회를 한다.
   * @param reqParam
   * @returns {Promise<any>}
   */
  search (reqParam) {
    return new Promise((resolve, reject) => {
      elasticsearchClient.search(reqParam, (err, resp, status) =>{
        if (status == '200') {
          resolve(resp);
        } else {
          reject(err);
        }
      })
    }).then((resp) => {
      return resp;
    });
  }
};

