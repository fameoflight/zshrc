import _ from 'lodash';
import axios from 'axios';

import requestsFactory, {RequestFactoryInstance} from './requestFactory';

function lmStudioClient(): RequestFactoryInstance {
	const LMSTUDIO_BASE_URL = 'http://localhost:1234';

	const axiosInstance = axios.create();

	return requestsFactory({
		baseURL: LMSTUDIO_BASE_URL,
		requestHeaders: new Map<string, string>([
			['Accept', 'application/json'],
			['Content-Type', 'application/json'],
		]),
		axiosClient: axiosInstance,
		retries: 0,
		callbacks: {
			onError: _response => {
				// log
			},
			onSuccess: _response => {
				// log
			},
		},
	});
}

export default {
	lmStudioClient,
};
