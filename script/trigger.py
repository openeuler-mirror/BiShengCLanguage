# -*- coding: utf-8 -*-
import requests
import argparse
import os
import base64

headers = {'Content-Type':'application/json', 'charset':'UTF-8'}
source_owner = 'openeuler'
repo = 'BiShengCLanguage'
ci_forks_owner = 'sunzibo'

llvm_branch = None
llvm_owner = None
llvm_PR_url = None
oac_branch = None
oac_owner = None
oac_PR_url = None
new_branch_name = None

def options(opt):
	opt.add_argument('--llvm', help='llvm PR id. This option is required')
	opt.add_argument('--oac', help='oac PR id. This option is required')
	opt.add_argument('--merge', action='store_true', dest='merge', help='merge.')
	opt.add_argument('--bsc', help='bsc PR id. This option is required')

def check_response(response):
	if response.status_code >= 200 and response.status_code < 300:
		print("Sending succeed!")
	else:
		print(response.json())
		parser.error("Sending failed!")

def BiShengCLanguage_ci_start(opt):
	global new_branch_name
	global llvm_branch
	global llvm_owner
	global oac_owner
	global oac_branch
	llvm_PR_url = None
	llvm_PR_api_url = None
	oac_PR_url = None
	oac_PR_api_url = None
	new_PR_comment = ""
	if opt.llvm:
		new_branch_name = 'ci_llvm_{}'.format(opt.llvm)
		llvm_PR_url = 'https://gitee.com/bisheng_c_language_dep/llvm-project/pulls/{0}'.format(opt.llvm)
		new_PR_comment = 'llvm_PR_url:{}\n'.format(llvm_PR_url)
		llvm_PR_api_url = 'https://gitee.com/api/v5/repos/bisheng_c_language_dep/llvm-project/pulls/{}'.format(opt.llvm)
		url = '{0}?access_token={1}'.format(llvm_PR_api_url, access_token)
		llvm_PR = get_PR(url)
		if not llvm_PR:
			parser.error('bisheng_c_language_dep/llvm-project does not has PR{}'.format(opt.llvm))
			return False
		else:
			llvm_branch, llvm_owner = handle_pr_value(llvm_PR, "llvm", opt.llvm)
			
	if opt.oac:
		new_branch_name = 'ci_oac_{}'.format(opt.oac)
		oac_PR_url = 'https://gitee.com/bisheng_c_language_dep/OpenArkCompiler/pulls/{0}'.format(opt.oac)
		new_PR_comment += 'oac_PR_url:{}'.format(oac_PR_url)
		oac_PR_api_url = 'https://gitee.com/api/v5/repos/bisheng_c_language_dep/OpenArkCompiler/pulls/{}'.format(opt.oac)
		url = '{0}?access_token={1}'.format(oac_PR_api_url, access_token)
		oac_PR = get_PR(url)
		if not oac_PR:
			parser.error('bisheng_c_language_dep/OpenArkCompiler does not has PR{}'.format(opt.oac))
			return False
		else:
			oac_branch, oac_owner = handle_pr_value(oac_PR, "oac", opt.oac)

	if opt.llvm and opt.oac:
		new_branch_name = 'ci_llvm_{0}_oac_{1}'.format(opt.llvm, opt.oac)
	bsc_PR = create_BiShengCLanguage_PR(opt)
	bsc_PR_url = bsc_PR.json()['url']
	comment_url_to_PR(bsc_PR_url, new_PR_comment)
	bsc_comment = 'bsc_PR_url:{}'.format(bsc_PR.json()['html_url'])
	if opt.llvm:
		comment_url_to_PR(llvm_PR_api_url, bsc_comment)
	if opt.oac:
		comment_url_to_PR(oac_PR_api_url, bsc_comment)

def comment_url_to_PR(url, comment):
	try:
		print("start commit url to PR!")
		url = '{}/comments'.format(url)
		data_value = '"access_token":"{0}","body":"{1}"'.format(access_token, comment)
		data = '{'+data_value+'}'
		response = requests.post(url, data=data, headers=headers)
		check_response(response)
		return response
	except Exception:
			pass
	return False

def handle_pr_value(pr_value, source, pr_id):
	state = pr_value.json()['state']
	if state != "open":
		print("state:"+state)
		parser.error('{0} PR {1} is not open!'.format(source, pr_id))
	branch = pr_value.json()['head']['label']
	owner = pr_value.json()['head']['user']['login']
	return branch, owner
	
def get_PR(url):
	try:
		print("repo_build_preflight!")
		response = requests.get(url, headers=headers)
		return response
	except Exception:
		pass
	return False
	
def create_BiShengCLanguage_PR(opt):
	try:
		title = ''
		create_branch_url = 'https://gitee.com/api/v5/repos/{0}/{1}/branches'.format(ci_forks_owner, repo)
		if create_branch("master", new_branch_name, create_branch_url):
			print("get file!")
			if opt.llvm:
				title = title + 'llvm id : {} '.format(opt.llvm)
				filename = 'llvm.commitid'
				file = set_file(filename, opt.llvm, llvm_owner, llvm_branch)
			if opt.oac:
				title = title + 'oac id : {}'.format(opt.oac)
				filename = 'oac.commitid'
				file = set_file(filename, opt.oac, oac_owner, oac_branch)
		print("start create BiShengCLanguage PR!")
		url = 'https://gitee.com/api/v5/repos/{}/BiShengCLanguage/pulls'.format(source_owner)
		data_value = '"access_token":"{1}","title":"{2}","head":"{0}:{3}","base":"master","prune_source_branch":"true","squash":"true"'.format(ci_forks_owner, access_token, title, new_branch_name)
		data = '{'+data_value+'}'
		response = requests.post(url, data=data, headers=headers)
		check_response(response)
		return response
	except Exception:
			pass
	return False
		
def set_file(filename, PRID, owner, branch):
	url_get_file = 'https://gitee.com/api/v5/repos/{3}/{0}/contents/{1}?access_token={2}'.format(repo, filename, access_token, ci_forks_owner)
	url_set_file = 'https://gitee.com/api/v5/repos/{2}/{0}/contents/{1}'.format(repo, filename, ci_forks_owner)
	try:
		print("start getfile " + filename)
		response = requests.get(url_get_file, headers=headers)
		check_response(response)

		print("start setfile " + filename)
		sha = response.json()['sha']
		message = 'fix ' + filename
		content = 'PRID:{0}\nowner:{1}\nbranch:{2}'.format(PRID, owner, branch)
		sample_string_bytes = content.encode("ascii")
		base64_bytes = base64.b64encode(sample_string_bytes)
		content = base64_bytes.decode("ascii")
		
		data_value = '"access_token":"{0}","content":"{1}","sha":"{2}","message":"{3}","branch":"{4}"'.format(access_token, content, sha, message, new_branch_name)
		data = '{'+data_value+'}'
		response = requests.put(url_set_file, data=data, headers=headers)
		check_response(response)
		return response
	except Exception:
		pass
	return False

def create_branch(refs, branch_name, url):
	try:
		print("start create new ci branch!")
		data_value = '"access_token":"{0}","refs":"{1}","branch_name":"{2}"'.format(access_token, refs, branch_name)
		data = '{'+data_value+'}'
		response = requests.post(url, data=data, headers=headers)
		check_response(response)
		return response
	except Exception:
		pass
	return False

def merge_BiShengCLanguage_PR(opt):
	parser.error("The development has not been completed!")

def get_access_token():
	global access_token
	try:
		path = os.popen('realpath ~/token').read().splitlines()[0]
		f = open(path, 'r')
		access_token = f.read().splitlines()[0]
	except IOError as e:
		print("IOError:",e) 
	finally:
		if f:
			f.close()
		
if __name__ == '__main__':
	get_access_token()
	parser = argparse.ArgumentParser()
	options(parser)
	opt = parser.parse_args()
	if opt.llvm or opt.oac and not opt.merge and not opt.bsc:
		BiShengCLanguage_ci_start(opt)
	elif opt.merge and opt.bsc and not opt.llvm and not opt.oac:
		merge_BiShengCLanguage_PR(opt)
	else:
		parser.error("")
