import requests
import optparse
import os
import base64

access_token = '351cdbba0be5979dda44b94e396f255c'
headers = {'Content-Type':'application/json', 'charset':'UTF-8'}
source_user = 'openeuler'
forks_url = 'https://gitee.com/api/v5/repos/{}/BiShengCLanguage/forks'.format(source_user)
forks_name = 'BiShengCLanguage'
forks_user = 'sunzibo'

llvm_branch = None
llvm_owner = None
oac_branch = None
oac_owner = None

def options(opt):
	opt.add_option('--llvm_id', '-l', type='string', action='store', dest='llvm_id', help='llvm PR id. This option is required')
	opt.add_option('--oac_id', '-o', type='string', action='store', dest='oac_id', help='oac PR id. This option is required')
	opt.add_option('--merge', '-m', action='store_true', dest='merge', help='merge.')
	opt.add_option('--bsc_id', '-b', type='string', action='store', dest='bsc_id', help='bsc PR id. This option is required')
	
def BiShengCLanguage_ci_start(opt):
	llvm_PR = None
	oac_PR = None
	if opt.llvm_id:
		url = 'https://gitee.com/api/v5/repos/bisheng_c_language_dep/llvm-project/pulls/{0}?access_token={1}'.format(opt.llvm_id, access_token)
		llvm_PR = get_PR(url)
		if not llvm_PR:
			print("error: bisheng_c_language_dep/llvm-project does not has PR"+opt.llvm_id)
			return False
		else:
			llvm_branch = llvm_PR.json()['head']['label']
			llvm_owner = llvm_PR.json()['head']['user']['login']
	if opt.oac_id:
		url = 'https://gitee.com/api/v5/repos/bisheng_c_language_dep/OpenArkCompiler/pulls/{0}?access_token={1}'.format(opt.oac_id, access_token)
		oac_PR = get_PR(url)
		if not oac_PR:
			parser.error("error: bisheng_c_language_dep/OpenArkCompiler does not has PR"+opt.oac_id)
			return False
		else:
			oac_branch = oac_PR.json()['head']['label']
			oac_owner = oac_PR.json()['head']['user']['login']

	bsc_PR = create_BiShengCLanguage_PR(opt)
	delete_forks()
	
def create_BiShengCLanguage_PR(opt):
	try:
		title = ''
		if forks():
			print("get file!")
			if opt.llvm_id:
				title = title + 'llvm id : {} '.format(opt.llvm_id)
				filename = 'llvm.commitid'
				file = set_file(filename, opt.llvm_id)
			if opt.oac_id:
				title = title + 'oac id : {}'.format(opt.oac_id)
				filename = 'oac.commitid'
				file = set_file(filename, opt.llvm_id)
		print("start create_BiShengCLanguage_PR!")
		url = 'https://gitee.com/api/v5/repos/{}/BiShengCLanguage/pulls'.format(source_user)
		data_value = '"access_token":"{1}","title":"{2}","head":"{0}:master","base":"master"'.format(forks_user, access_token, title)
		data = '{'+data_value+'}'
		response = requests.post(url, data=data, headers=headers)
		if not response:
			print("error:create_BiShengCLanguage_PR failed!")
			print(response.json())
		return response
	except Exception:
			pass
	return False
		
def set_file(filename, id):
	url_get_file = 'https://gitee.com/api/v5/repos/{3}/{0}/contents/{1}?access_token={2}'.format(forks_name, filename, access_token, forks_user)
	try:
		print("start getfile " + filename)
		response = requests.get(url_get_file, headers=headers)
		if not response:
			parser.error('get {} failed!'.format(filename))
			print(response.json())
			return False
		print("start setfile " + filename)
		url_set_file = 'https://gitee.com/api/v5/repos/{2}/{0}/contents/{1}'.format(forks_name, filename, forks_user)
		sha = response.json()['sha']
		message = 'fix ' + filename
		content = 'id:' + id
		sample_string_bytes = content.encode("ascii")
		base64_bytes = base64.b64encode(sample_string_bytes)
		content = base64_bytes.decode("ascii")
		data_value = '"access_token":"{0}","content":"{1}","sha":"{2}","message":"{3}","branch":"master"'.format(access_token, content, sha, message)
		data = '{'+data_value+'}'
		response = requests.put(url_set_file, data=data, headers=headers)
		if not response:
			parser.error('set {} failed!'.format(filename))
			print(response.json())
			return False
		return True
	except Exception:
		pass
	return False
		
def forks():
	try:
		print("start forks openeuler/BiShengCLanguage to sunzibo/BiShengCLanguage!")
		data_value = '"access_token":"{}"'.format(access_token)
		data = '{'+data_value+'}'
		response = requests.post(forks_url, data=data, headers=headers)
		if not response:
			print(response.json())
			print("error:forks BiShengCLanguage failed!")
		return response
	except Exception:
		pass
	return False
	
def delete_forks():
	try:
		print("start delete forks!")
		path = forks_name
		url = 'https://gitee.com/api/v5/repos/{2}/{0}?access_token={1}'.format(forks_name, access_token, forks_user)
		response = requests.delete(url, headers=headers)
		if not response:
			print("error:delete_forks failed!")
			print(response.json())
		return response
	except Exception:
		pass
	return False
		
		
def get_PR(url):
	try:
		print("repo_build_preflight!")
		response = requests.get(url, headers=headers)
		return response
	except Exception:
		pass
	return False

if __name__ == '__main__':
	usage = "Usage: %prog -l llvm_id -o oac_id or %prog --merge -b bsc_id"
	description = ""
	parser = optparse.OptionParser(usage, description=description)
	options(parser)
	opt, args = parser.parse_args()
	if len(args) != 0:
		parser.error("")
	elif opt.llvm_id or opt.oac_id and not opt.merge and not opt.bsc_id:
		BiShengCLanguage_ci_start(opt)
	elif opt.merge and opt.bsc_id and not opt.llvm_id and not opt.oac_id:
		merge_BiShengCLanguage_PR(opt)
	else:
		parser.error("")