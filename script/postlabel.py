# -*- coding: utf-8 -*-
import requests
import sys
import argparse

headers = {'Content-Type':'application/json', 'charset':'UTF-8'}
llvm_project = 'bisheng_c_language_dep/llvm-project'
oac_project = 'bisheng_c_language_dep/OpenArkCompiler'

def check_response(response):
    if response.status_code >= 200 and response.status_code < 300:
        print("post label succeed!")
    else:
        print(response.json())
        print("error:post label failed!")
        return False
    return True

def create_label(project, id, label):
	try:
		print('start post label:{}!'.format(label))
		url = 'https://gitee.com/api/v5/repos/{0}/pulls/{1}/labels?access_token={2}'.format(project, id, access_token)
		data = '[\"{}\"]'.format(label)
		response = requests.post(url, data=data, headers=headers)
		if check_response(response):
		    print('post label:{} end!'.format(label))
		    return response
	except Exception:
		pass
	return None

def delete_label(project, id, label):
	try:
		print('start delete label:{}!'.format(label))
		url = 'https://gitee.com/api/v5/repos/{0}/pulls/{1}/labels/{2}?access_token={3}'.format(project, id, label, access_token)
		response = requests.delete(url, headers=headers)
		if check_response(response):
		    print('delete label:{} end!'.format(label))
		    return response
	except Exception:
		pass
	return None

def start_post_label(project, id, label):
	response = None
	if label == 'ci_processing':
		delete_label(project, id, 'ci_successful')
		delete_label(project, id, 'ci_failed')
		response = create_label(project, id, label)
	elif label == 'ci_successful' or label == 'ci_failed':
		delete_label(project, id, 'ci_processing')
		delete_label(project, id, 'ci_successful')
		delete_label(project, id, 'ci_failed')
		response = create_label(project, id, label)
	else:
		print("please post right label!(ci_processing or ci_successful or ci_failed)")
	if not response:
		sys.exit("Failed to send the tag. Check the PR and token.")

def options(opt):
	opt.add_argument('--llvm', default="-1", help='llvm PR id. This option is required')
	opt.add_argument('--oac', default="-1", help='oac PR id. This option is required')
	opt.add_argument('--label', help='label. This option is required')
	opt.add_argument('--token', help='accsee token. This option is required')

if __name__ == '__main__':
	global access_token
	parser = argparse.ArgumentParser()
	options(parser)
	args = parser.parse_args()
	access_token = args.token
	if args.llvm != "-1":
		start_post_label(llvm_project, args.llvm, args.label)
	if args.oac != "-1":
		start_post_label(oac_project, args.oac, args.label)
