/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import { Permissions } from '@ohos.abilityAccessCtrl';

/**
 * 所有功能的通用常量
 * 定义了插件使用的各种常量值
 */
export class CommonConstants {
	/**
	 * 请求的权限列表
	 * 包含定位相关的权限
	 * ohos.permission.APPROXIMATELY_LOCATION: 模糊定位权限
	 * ohos.permission.LOCATION: 精确定位权限
	 */
	static readonly REQUEST_PERMISSIONS: Array<Permissions> = [
		'ohos.permission.APPROXIMATELY_LOCATION',
		'ohos.permission.LOCATION',
	];

	/**
	 * 初始化值
	 * 用于各种需要初始化的场景
	 */
	static readonly INITIALIZATION_VALUE: string = '0';
}