import requests
import sys

access_token = '351cdbba0be5979dda44b94e396f255c'
headers = {'Content-Type':'application/json', 'charset':'UTF-8'}
llvm_project = 'bisheng_c_language_dep/llvm-project'
oac_project = 'bisheng_c_language_dep/OpenArkCompiler'

def check_response(response):
	if not response:
		print(response.json())
		print("error:post does not has return!")

def create_label(project, id, label):
	try:
		print('start post label:{}!'.format(label))
		url = 'https://gitee.com/api/v5/repos/{0}/pulls/{1}/labels?access_token={2}'.format(project, id, access_token)
		data = '[\"{}\"]'.format(label)
		response = requests.post(url, data=data, headers=headers)
		check_response(response)
		print('post label:{} end!'.format(label))
		return response
	except Exception:
		pass
	return False

def delete_label(project, id, label):
	try:
		print('start delete label:{}!'.format(label))
		url = 'https://gitee.com/api/v5/repos/{0}/pulls/{1}/labels/{2}?access_token={3}'.format(project, id, label, access_token)
		response = requests.delete(url, headers=headers)
		check_response(response)
		print('delete label:{} end!'.format(label))
		return response
	except Exception:
		pass
	return False

def start_post_label(project, id, label):
	if label == 'ci_processing':
		delete_label(project, id, 'ci_successful')
		delete_label(project, id, 'ci_failed')
		create_label(project, id, label)
	elif label == 'ci_successful' or label == 'ci_failed':
		delete_label(project, id, 'ci_processing')
		delete_label(project, id, 'ci_successful')
		delete_label(project, id, 'ci_failed')
		create_label(project, id, label)
	else:
		print("please post right label!(ci_processing or ci_successful or ci_failed)")

if __name__ == '__main__':
	label = sys.argv[1]
	llvm_id = sys.argv[2]
	oac_id = sys.argv[3]
	if llvm_id != "-1":
		start_post_label(llvm_project, llvm_id, label)
	if oac_id != "-1":
		start_post_label(oac_project, oac_id, label)
